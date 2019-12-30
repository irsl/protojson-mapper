package MapLogic;

use strict;
use warnings;
use LWP::UserAgent;
use JSON; 
use Digest::SHA1  qw( sha1_hex );
use Data::Dumper;	
use File::Basename;
	
use Common;

sub new {
    my $class   = shift;
	my $URL     = shift;
	my $ORIGIN  = shift;
	my $COOKIES = shift;

	die "Mandatory params missing" if(!$COOKIES);
	
	my $SAPISID = _extract_sapisid($COOKIES);

	my $ua = LWP::UserAgent->new();
	$ua->agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:71.0) Gecko/20100101 Firefox/71.0");
	$ua->default_header(Cookie=> $COOKIES);
	$ua->default_header("X-Goog-AuthUser"=> "0");
	$ua->default_header("Origin" => $ORIGIN);
	if($ENV{DEBUG_LWP}) {
		$ua->add_handler("request_send",  sub { print STDERR shift->as_string."\n\n"; return });
		$ua->add_handler("response_done", sub { print STDERR shift->as_string."\n\n\n\n"; return });
	}

    my $re = {
	   URL => $URL,
	   ORIGIN => $ORIGIN,
	   SAPISID => $SAPISID,
	   ua => $ua,
	};

    return bless $re, $class;
}

sub process {
   my $this = shift;
   $this->{error_count} = 0;
   $this->{payload} = [];
   $this->{depth} = 0;
   $this->{protobuf} = [];
   while(1){
      if(!$this->_process()) {
	     Common::mydebug("Found no more fields at level $this->{depth}");
		 last if($this->{depth} <= 0);
		 
		 # trying one level higher
		 $this->{depth}--;
	  }
	  
   }

   $this->_fixup_repeatable($this->{protobuf});

   return $this->{protobuf};
}

sub _fixup_repeatable {
  my $this = shift;
  my $protobuf = shift;

  for my $def (@$protobuf) {
	  next if(!$def->{is_complex_type});
	  
 	  if((scalar @{$def->{subtypes}} == 1)&&($def->{subtypes}->[0]->{looks_like_repeatable}))
 	  {
		 $def->{repeated} = 1;
		 $def->{subtypes} = $def->{subtypes}->[0]->{subtypes};
	  }

      $this->_fixup_repeatable($def->{subtypes});
  }
}

sub _process {
   my $this = shift;
   
   my ($payload_target, $protobuf_target, $name) = $this->get_last_stuff_from_payload($this->{depth});
   if((scalar @$protobuf_target)&&($protobuf_target->[scalar @$protobuf_target-1]->{looks_like_repeatable})) {
      Common::mydebug("We are in the middle of an array, not adding any more fields here");
	  return 0;
   }
   my $c = scalar @$payload_target;
   push @$payload_target, JSON::false;
   
   Common::mydebug("Trying to get more fields for $name at depth $this->{depth}");
   my $res = $this->send_request();
   
   my $err = $this->get_new_error($res);
   if(!$err) {
       # there were no new errors. we need to try a different type to prevent matching with a truly boolean field
	   $payload_target->[$c] = 1234;
	   $res = $this->send_request();
	   $err = $this->get_new_error($res);
	   if(!$err) {
	      Common::mydebug("Found no more fields for $name at depth $this->{depth}; trying one more stuff just to be sure it is not an any field");
		  
		  my $original = decode_json(encode_json($this->{payload}));
		  
		  push @$payload_target, JSON::false;
          $res = $this->send_request();
		  my $really_last_try_err = $this->get_new_error($res);
		  if(!$really_last_try_err) {
		  
              Common::mydebug("there are still no new errors. this means there are no more parameters at this level");
		 	  return 0;
		  }
		  
		  Common::mydebug("wohoho! we detected an any field.");
		  
		  $this->{payload} = $original;

		  $err = {};
		  $err->{field} = "unknown_any_field";
		  $err->{type} = "any";
		  $err->{is_complex_type} = 0;
		  $err->{is_simple_type} = 0;
		  $err->{is_enum} = 0;

          # remember, there were no errors reported for this any field
          $this->{error_count}--;
	   }
   }

   Common::mydebug(">>>>>>>>>> Found a new field for $name at depth $this->{depth} >>>> $err->{field}: $err->{type}");
   
   if($err->{is_enum}) {
      # need to find the min and the max of the enum options
	  # TODO
      Common::mydebug("Trying to determine available options for the enum field $name");
   }
   
   # so we just identified one more error.
   $this->{error_count}++;
   
   push @$protobuf_target, $err;
   
   if($err->{is_complex_type}) {
      $payload_target->[$c] = []; # upgrading to a complex type
      $this->{depth}++;
	  $this->{error_count}--;
   }

   if($ENV{DEBUG_CODEFLOW}) {
	   Common::mydebug(Dumper($this->{payload}));
	   Common::mydebug(Dumper($this->{protobuf}));
	   Common::mydebug(Dumper($res));
	   Common::mydebug("error count: $this->{error_count}");   
	   <STDIN>;
   }

   return 1;   
}

sub get_new_error 
{
   my $this = shift;
   my $r = shift;
   return if(!$r->{error});
   return if(!$r->{error}->{message});
   my @act_errors = split("\n", $r->{error}->{message});
   my $c_act_errors = scalar @act_errors;
   return if( $c_act_errors <= $this->{error_count});
   my $err_message = $act_errors[$c_act_errors-1];
   return if($err_message !~ /at '([^']+)' \(([^)]+)\)/);
   my $re = { full_field=>$1, field=>$1, full_type=>$2, type=>$2 };
   if($re->{full_field} =~ /\[0\]$/)
   {
      $re->{looks_like_repeatable} = 1;
   }
   $re->{field} = $1 if($re->{full_field} =~ /.+\.(.+)/);
   if($re->{full_type} =~ m#type.googleapis.com/(.+)\.(.+)#) {
      $re->{package} = $1;
      $re->{type} = $2;
   }
   $re->{is_enum} = $re->{type} eq "TYPE_ENUM" ? 1 : 0;
   $re->{is_simple_type} = ($re->{type} =~ /^TYPE_/ ? 1 : 0);
   if($re->{is_simple_type}) {
      $re->{type} = lc(substr($re->{type}, 5));
   }
   if($re->{type} eq "BOOL") {
      $re->{is_simple_type} = 1;
      $re->{type} = "bool";
   }
   $re->{is_complex_type} = $re->{is_simple_type} ? 0 : 1;
   if($re->{is_complex_type}) {
      $re->{subtypes} = [];
   }
   return $re;
}

sub get_last_stuff_from_payload {
   my $this = shift;
   my $depth = shift;
   
   if($ENV{DEBUG_CODEFLOW}) {
	   Common::mydebug("get_last_stuff_from_payload: $depth");
	   Common::mydebug(Dumper($this->{payload}));
	   Common::mydebug(Dumper($this->{protobuf}));
   }
   my $re_payload = $this->{payload};
   my $re_protobuf = $this->{protobuf};
   my $name = "request";
   while($depth > 0) {
      my $c = scalar @$re_payload - 1;
	  $re_payload = $re_payload->[$c];
	  $name = $re_protobuf->[$c]->{field};
	  $re_protobuf = $re_protobuf->[$c]->{subtypes};
      $depth--;
	  
	   Common::mydebug("... internal get_last_stuff_from_payload: $depth");
	   Common::mydebug(Dumper($re_payload));
	   Common::mydebug(Dumper($re_protobuf));
	   Common::mydebug("name: $name");
	  
   }
   return ($re_payload, $re_protobuf, $name);   
}

sub send_request {
    my $this = shift;
	my $payload = $this->{payload};

	my $now = time();
	my $sapidhash = sha1_hex($now." ".$this->{SAPISID}." ".$this->{ORIGIN});

	my $res = $this->{ua}->post(
	  "$this->{URL}&alt=protojson",

	  "Authorization" => "SAPISIDHASH ${now}_${sapidhash}",
	  "Content-Type"  => "application/json+protobuf",

	  Content=> encode_json($payload),
	);

    return decode_json($res->content);
}

sub _extract_sapisid {
   my $cookies = shift;
   die "SAPISID not found among the cookies" if($cookies !~ /SAPISID=([^;\s]+)/);
   return $1;
}

sub dump_protobuf_definition {
   my $this = shift;
   my $methodName = basename($this->{URL});
   if($methodName =~ /(.+)\?/) {
      $methodName = $1;
   }
   my $className = "Request${methodName}";
   my $re = _dump_protobuf_definition($className, $this->{protobuf}, 0);
   $re .= "\n\n// ".encode_json($this->{protobuf})."\n";
=verify
   # we could verify if it is syntactically correct:
    use Google::ProtocolBuffers; Google::ProtocolBuffers->parse($re,{create_accessors => 1 });my $x = $className->new;print Dumper($x);
	use Class::MOP;
	my $meta = Class::MOP::Class->initialize($className);
	for my $meth ( $meta->get_all_methods ) {print $meth->fully_qualified_name, "\n";}
	exit;
=cut
   return $re;
}

sub _dump_protobuf_definition {
   my $message_type_name = shift;
   my $defs = shift;
   my $level = shift;
   my $i = 0;
   my $indenting = ((" "x($level*2)));
   my $re = sprintf "%s%s %s {\n", $indenting, "message", $message_type_name;
   
   # lets dump the definition of complex types first
   my %already;
   for my $def (@$defs) {
	  if($def->{is_complex_type}) {
	     next if($already{$def->{type}});
		 $already{$def->{type}}=1;
		 $re .= _dump_protobuf_definition($def->{type}, $def->{subtypes}, $level+1);
		 $re .= "\n";
	  }
   }
   # lets put out something about enums
   for my $def (@$defs) {
	  if($def->{is_enum}) {
         $def->{enum_type} = $def->{field}."_enum";
	     $re .= sprintf("%s  enum %s {\n", $indenting, $def->{enum_type});
		 $re .= sprintf("%s    %s_UNKNOWN = 0;\n", $indenting, uc($def->{field}));
	     $re .= sprintf("%s  }\n", $indenting);
		 $re .= "\n";
	  }
   }
   for my $def (@$defs) {
      $i++;
      $re .= sprintf "%s  %s %-40s = %d;\n", $indenting, ($def->{repeated} ? "repeated" : "optional"), ($def->{is_enum} ? $def->{enum_type} : $def->{type})." ". $def->{field}, $i;
   }
   $re.= sprintf "%s}\n", $indenting;
   
   return $re;
}

sub ReadProtoFile {
   my $pathToProtomap = shift;
   my $content = Common::slurp($pathToProtomap);
   my @lines = split(/\n/, $content);
   my $last = $lines[scalar @lines -1];
   die "Invalid protofile" if($last !~ m#// (.+)#);
   return decode_json($1);
}

sub ProtoBufToSimpleJson {
  my $protobuf = shift;
  my $protojson = shift;
  my $re = {};
  die "arrayref expected" if(ref $protojson ne "ARRAY");
  for (my $i = 0; $i < scalar @$protojson; $i++) {
     my $a_protojson = $protojson->[$i];
	 next if(!defined($a_protojson));
	 my $a_protobuf = $protobuf->[$i];
	 if($a_protobuf->{repeated}) {
    	 $re->{$a_protobuf->{field}} = [];
		 for my $v (@$a_protojson) {
		    push @{$re->{$a_protobuf->{field}}}, ProtoBufToSimpleJson($a_protobuf->{subtypes}, $v); 	 		 
		 }
	 }else{
    	 $re->{$a_protobuf->{field}} = $a_protobuf->{is_complex_type} ? ProtoBufToSimpleJson($a_protobuf->{subtypes}, $a_protojson) : $a_protojson; 
	 }
  }
  return $re;
}

1;

package Common;

use strict;
use warnings;
use JSON;

sub mydebug {
  my $msg = shift;
  return if(!$ENV{DEBUG});
  my $now = localtime;
  print STDERR "[$now] $msg\n";
}

sub slurp {
  my $fp = shift;
  my $buf;
  if($fp) {
    open(my $h, "<$fp") or die "cant: $!";
    binmode($h);
    read($h, $buf, -s $fp);
    close($h);
  }else{
    $buf = do { local $/; <STDIN> };
  }
  return $buf;
}

sub read_json_from_stdin {
   return decode_json(slurp());
}

1;

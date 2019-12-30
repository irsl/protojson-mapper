#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MapLogic;
use Common;

my $proto_path = shift @ARGV;
die "Usage: $0 mapfile.proto < protojson.json\n" if((!$proto_path)||(!-s $proto_path));

my $protobuf = MapLogic::ReadProtoFile($proto_path);
my $protojson = Common::read_json_from_stdin();
my $simplejson = MapLogic::ProtoBufToSimpleJson($protobuf, $protojson);
print to_json($simplejson,  {utf8 => 1, pretty => 1});

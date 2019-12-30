#!/usr/bin/perl

use strict;
use warnings;
use JSON; 
use Data::Dumper;	
use FindBin qw($Bin);
use lib "$Bin/lib";
use MapLogic;
use Common;

my $URL     = shift @ARGV || $ENV{URL};
my $ORIGIN  = shift @ARGV || $ENV{ORIGIN};
my $COOKIES = shift @ARGV || $ENV{COOKIES};

die "Usage: $0 url origin cookies

Example: perl $0 \"https://chat-pa.clients6.google.com/chat/v1/presence/querypresence?key=AIzaSyD7InnYR3VKdb4j2rMUEbTCIr2VyEazl6k\" https://hangouts.google.com \"SID=...; HSID=...; SSID=...; APISID=...; SAPISID=...\"

" if(!$COOKIES);

local $| = 1;

my $maplogic = MapLogic->new($URL, $ORIGIN, $COOKIES);

if(!$ENV{PREPROCESSED})
{
    $maplogic->process();

	Common::mydebug("Ready with the online activity!");
	
}else {
   Common::mydebug("reading preprocessed protobuf from $ENV{PREPROCESSED}");
   $maplogic->{protobuf} = decode_json(Common::slurp($ENV{PREPROCESSED}));
}

print $maplogic->dump_protobuf_definition();


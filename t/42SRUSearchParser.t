#!perl -Tw

use strict;

use Test::More tests => 6;

use PICA::SRUSearchParser;
use PICA::XMLParser;

open SRU, "t/searchRetrieveResponse-1.xml";
my $xml = join("",<SRU>);
close SRU;

my $xmlparser = new PICA::XMLParser();
my $parser = PICA::SRUSearchParser->new( $xmlparser );
$parser->parse( $xml );

is( $parser->numberOfRecords, 2 );
is( $parser->resultSetId, "SID68ddfabd-11a4S4" );
is( $parser->currentNumber, 2);
is( $xmlparser->counter(), 2 );

$parser = PICA::SRUSearchParser->new();
$xmlparser = $parser->parse( $xml );
is( $xmlparser->counter(), 2 );
is( $parser->currentNumber, 2);
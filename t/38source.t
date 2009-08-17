#!perl -Tw

use strict;
use warnings;
use utf8;

use Test::More qw(no_plan);
use Encode;
use PICA::Source;

my $HTTPRESPONSE;

no warnings 'redefine';
*LWP::Simple::get = sub($) { return $HTTPRESPONSE; };

$HTTPRESPONSE = '%1E021A+%1FaEine+%40Reise+in+den+Su%CC%88den%1E011%40+%1Fa2009';
my $source = PICA::Source->new( PSI => "http://example.com" );
my $record = $source->getPPN( 12345 );
is( "$record", "021A \$aEine \@Reise in den Süden\n011\@ \$a2009\n", 'getPPN via PSI' );


#### SRU

use PICA::SRUSearchParser;
use PICA::XMLParser;

open SRU, "t/files/searchRetrieveResponse-1.xml";
my $xml = join("",<SRU>);
close SRU;

my $xmlparser = new PICA::XMLParser();
my $parser = PICA::SRUSearchParser->new( $xmlparser );
$parser->parse( $xml );

is( $parser->numberOfRecords, 2, 'SRU response' );
is( $parser->resultSetId, "SID68ddfabd-11a4S4" );
is( $parser->currentNumber, 2);
is( $xmlparser->counter(), 2 );


$parser = PICA::SRUSearchParser->new();
$xmlparser = $parser->parse( $xml );
is( $xmlparser->counter(), 2 );
is( $parser->currentNumber, 2);


$HTTPRESPONSE = $xml;
$source = PICA::Source->new( SRU => "http://example.com" );
my @records = $source->cqlQuery("pica.ppn=123")->records();
is( scalar @records, 2, 'SRU cql query' );

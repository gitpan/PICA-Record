#!perl -Tw

use strict;

use Test::More tests => 3;

use PICA::SRUSearchParser;

my $record;
my $record_count=0;
sub handle_record { $record = shift; $record_count++; }

open SRU, "t/searchRetrieveResponse-1.xml";
my $xml = join("",<SRU>);
close SRU;

# Create a parser and parse the example file
my $parser = PICA::SRUSearchParser->new( Record => \&handle_record );
$parser->parseResponse($xml);

isa_ok( $record, 'PICA::Record' );
ok ( $record_count == 2, 'PICA::SRUSearchParser' );

ok ( $parser->counter() == 2, 'PICA::SRUSearchParser->counter' );


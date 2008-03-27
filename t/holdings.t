#!perl -Tw

use strict;
use Test::More tests => 6;

use PICA::Parser qw(parsefile);

my $picafile = "t/bgb.example";
my $record;

parsefile( $picafile, Record => sub { $record = shift; } );
isa_ok( $record, 'PICA::Record' );

my @holdings = $record->local_records();
ok( scalar @holdings == 56, "local_records" );

my @copies = $record->copy_records();
ok( scalar @copies == 336, "copy_records" );

ok( scalar $holdings[0]->copy_records() == 1, "copy_records (1)");
ok( scalar $holdings[4]->copy_records() == 2, "copy_records (2)");
ok( scalar $holdings[5]->copy_records() == 26, "copy_records (26)");

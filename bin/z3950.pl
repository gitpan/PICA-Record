#!/usr/bin/perl

use strict;
use utf8;
use ZOOM;
use PICA::Server;

# the query
my $query = '@attr 1=4 "Landpartie Jahresanthologie"';

# handle the records with this function
sub record_handler {
    my $record = shift;
    $record->sort();
    # print $record->normalized();
    print $record->subfield('021A$a') . "\n"; # print the title
    return $record; # don't drop records
}

# connect and query via Z39.50
my $gso = PICA::Server->new(Z3950 => "z3950.gbv.de:20012/gvk");
my $parser = $gso->z3950Query( $query, Record => \&record_handler );

print "\nRead " . $parser->counter() . " records\n";


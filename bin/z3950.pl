#!/usr/bin/perl

=head1 NAME

z3950 - get PICA+ from Z39.50 server

=cut

use strict;
use utf8;
use ZOOM;
use PICA::Server;

# include other packages
use Getopt::Long;
use Pod::Usage;

my $host = shift @ARGV;
my $query = shift @ARGV;
pod2usage(2) unless defined $host and defined $query;

my $user = scalar @ARGV ? shift @ARGV : "";
my $password = scalar @ARGV ? shift @ARGV : "";


# handle the records with this function
sub record_handler {
    my $record = shift;
    $record->sort();
    print $record->normalized();
    #print $record->subfield('021A$a') . "\n"; # print the title
    return $record; # don't drop records
}

# connect and query via Z39.50
my $gso = PICA::Server->new( Z3950 => $host, password=>$password, user=>$user );
my $parser = $gso->z3950Query( $query, Record => \&record_handler );

print "\nRead " . $parser->counter() . " records\n";


=head1 SYNOPSIS

z3950.pl host query [user password]

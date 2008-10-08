#!/usr/bin/perl

=head1 NAME

z3950.pl - Get PICA+ records from a Z39.50 server

=cut

use strict;
use utf8;
use ZOOM;
use PICA::Server;

# include other packages
use Getopt::Long;
use Pod::Usage;

my ($user, $password, $help, $man);
GetOptions(
    'help|?' => \$help,
    'man' => \$man,
    'user=s' => \$user,
    'password=s' => \$password
) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

my $host = shift @ARGV;
my $query = join " ", @ARGV;
pod2usage(1) unless $host and $query ne '';

# handle the records with this function
sub record_handler {
    my $record = shift;

    print $record->to_string() . "\n";

    return $record; # don't drop records
}

# connect and query via Z39.50
my $gso = PICA::Server->new(
    Z3950 => $host, password => $password, user => $user 
);
my $parser = $gso->z3950Query( $query, Record => \&record_handler );

print "Read " . $parser->counter() . " PICA+ records\n";

=head1 SYNOPSIS

z3950.pl [OPTIONS] host[:port]/databaseName query...

=head1 OPTIONS

 -help|H|?        this help message
 -man             more documentation with examples
 -user USER       username for authentification (optional)
 -password PWD    password for authentification (optional)

=head1 DESCRIPTION

This script demonstrates how to query and PICA+ records from a Z39.50 server.


=head1 EXAMPLES

Get records from GVK union catalog with 'microformats' in its title:

  z3950.pl z3950.gbv.de:20012/GVK @attr 1=4 microformats

=head1 AUTHOR

Jakob Voss C<< jakob.voss@gbv.de >>

#!/usr/bin/perl

=head1 NAME

gbvholdings.pl - get holding information in GBV union catalog for a given ISBN

=cut

use PICA::Server;

my $isbn = shift @ARGV;

my @status;
if ($isbn) {
    my $server = PICA::Server->new(
        SRU => "http://gso.gbv.de/sru/DB=2.1/"
    );
    $server->cqlQuery( 'pica.isb=' . $isbn , 
        Record => sub { 
            $record = shift;
            my @bib = $record->values( '101@$d' );
            push @status, @bib;
        }
    );
    @status = ("ISBN $isbn not found") unless @status;
    print join("\n", @status) . "\n";
} else {
    print "Usage: $0 <ISBN>\n";
}
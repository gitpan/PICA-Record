#!/usr/bin/perl

=head1 NAME

gbvholdings.pl - get holding information in GBV union catalog for a given ISBN

=cut

use PICA::Server;

my $isbn = shift @ARGV;

my @status;
if ($isbn) {
    my $cql = 'pica.isb=' . $isbn;
    my $url = "http://gso.gbv.de/sru/DB=2.1/";

    print "SRU query '$cql' to $url\n";

    my $server = PICA::Server->new( SRU => $url );
    $server->cqlQuery( $cql,
        Record => sub { 
            $record = shift;
            my @fields = $record->field('101@|209A/..');
            foreach my $f (@fields) {
                if ($f->tag eq '101@') { # new library
                    print "Location: " . $f->subfield('d') . "\n";
                } else {
                    print "  sublocation: " . $f->subfield('f') ."\n";
                    print "    call-number: " . $f->subfield('a') ."\n";
                }
            }
        }
    );
} else {
    print "Usage: $0 <ISBN>\n";
}
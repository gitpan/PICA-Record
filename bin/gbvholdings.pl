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

    my $server = PICA::Server->new( SRU => $url );
    $server->cqlQuery( $cql,
        Record => sub { 
            $record = shift;
            my @local = $record->local_records();
            foreach my $l (@local) {
                print "Location: " . $l->subfield('101@$d') . "\n";
                my @copies = $l->copy_records();
                foreach my $c (@copies) {
                    print "  sublocation: " . $c->subfield('209A/..$f') ."\n";
                    print "    call-number: " . $c->subfield('209A/..$a') ."\n";
                }
            }
        }
    );
} else {
    print "Usage: $0 <ISBN>\n";
}
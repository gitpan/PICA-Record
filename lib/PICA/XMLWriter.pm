package PICA::XMLWriter;

=head1 NAME

PICA::XMLWriter - Write and count PICA+ records and fields in XML format

=cut

use strict;
use warnings;

use PICA::Writer;

use Carp;

use vars qw($VERSION @ISA);
@ISA = qw( PICA::Writer );
$VERSION = "0.31";

=head1 METHODS

=head2 write

Write a record(s) of type L<PICA::Record>. You can also pass 
strings that will be printed as comments.

=cut

sub write {
    my $self = shift;

    my $comment = "";
    while (@_) {
        my $record = shift;

        if (ref($record) eq 'PICA::Record') {
            if ( $self->{filehandle} ) {
                $self->start_document() unless $self->{in_doc};
                print { $self->{filehandle} } $record->to_xml() ;
            }
            $comment = "";

            $self->{recordcounter}++;
            $self->{fieldcounter} += scalar $record->all_fields;
        } elsif (ref(\$record) eq 'SCALAR') {
            next if !$record;
            $comment .= "\n" if $comment;
            $comment .= '# ' . join("\n# ", split(/\n/,$record)) . "\n";
        } else {
            croak("Cannot write object of unknown type (PICA::Record expected)!");
        }
    }
}

=head2 start_document

Write XML header and collection start element.

=cut

sub start_document {
    my $self = shift;
    print { $self->{filehandle} } "<?xml version='1.0' encoding='UTF-8'?>\n<collection>\n" if $self->{filehandle};
    $self->{in_doc} = 1;
}

=head2 end_document

Write XML footer (collection end element).

=cut

sub end_document {
    my $self = shift;
    print { $self->{filehandle} } "</collection>\n" if $self->{filehandle} and $self->{in_doc};
    $self->{in_doc} = 0;
}

1;

__END__

=head1 TODO

Support writing single fields without breaking the XML structure. 

A namespace is needed (must be supplied by OCLC PICA).

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007 by Verbundzentrale Goettingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.


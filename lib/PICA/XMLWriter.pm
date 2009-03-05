package PICA::XMLWriter;

=head1 NAME

PICA::XMLWriter - Write and count PICA+ records and fields in XML format

=cut

use strict;
use utf8;

use base qw( PICA::Writer );
our $VERSION = "0.44";

#use PICA::Writer;
use Carp qw(croak);

our $NAMESPACE = 'info:srw/schema/5/picaXML-v1.0';

=head1 METHODS

=head2 new ( [ <file-or-handle> ] [, %parameters ] )

Create a new XML writer.

=cut

sub new {
    my $class = shift;
    my ($fh, %params) = @_ % 2 ? @_ : (undef, @_);
    my $self = bless { 
        header => $params{header},
        xslt => $params{xslt},
        collection => defined $params{collection} ? $params{collection} : 1,
    }, $class;
    return $self->reset($fh);
}

=head2 write ( [ $comment, ] $record [, $record ... ] )

Write a record(s) of type L<PICA::Record>. You can also pass
strings that will be printed as comments. Please make sure to
have set the default namespace ('info:srw/schema/5/picaXML-v1.0')
to get valid PICA XML.

This method does not write an XML header and footer but you can
easily chain method calls like this:

  $writer->start_document()->write($record)->end_document();

=cut

sub write {
    my $self = shift;

    my $comment = "";
    while (@_) {
        my $record = shift;

        if (ref($record) eq 'PICA::Record') {
            if ( $self->{filehandle} ) {
                print { $self->{filehandle} } $record->to_xml() ;
            }
            $comment = "";

            $self->{recordcounter}++;
            $self->{fieldcounter} += scalar $record->all_fields;
        } elsif (ref(\$record) eq 'SCALAR') {
            next if !$record;
            $comment .= "\n" if $comment;
            $comment .= '# ' . join("\n# ", split(/\n/,$record)) . "\n";
            $comment =~ s/--//g;
            print "<!-- $comment -->";
        } else {
            croak("Cannot write object of unknown type (PICA::Record expected)!");
        }
    }
    $self;
}

=head2 writefield ( $field [, $field ... ] )

Write one ore more C<PICA::Field> in XML, based on C<PICA::Field->to_xml>.

=cut

sub writefield {
    my $self = shift;
    while (@_) {
        my $field = shift;
        if (ref($field) ne 'PICA::Field') {
            croak("Cannot write object of unknown type (PICA::Field expected)!");
        } else {
            print { $self->{filehandle} } $field->to_xml() if $self->{filehandle};
            $self->{fieldcounter}++;
        }
    }
}

=head2 start_document ( [ %params ] )

Write XML header and collection start element. 
The default namespace is set to 'info:srw/schema/5/picaXML-v1.0'.

Possible parameters include 'stylesheet' to add an XSLT script reference.

=cut

sub start_document {
    my $self = shift;
    my %params = @_;

    # TODO: see PICA::Record->to_xml and combine
    my @xml;

    if ($params{header}) {
        push @xml, "<?xml version='1.0' encoding='UTF-8'?>";
        $params{collection} = 1;
    }

    if ($self->{filehandle}) {
        push @xml, "<?xml version='1.0' encoding='UTF-8'?>";
        if ($params{xslt}) {
            my $xslt = $params{xslt};
            $xslt =~ s/'/&apos/;
            push @xml, "<?xml-stylesheet type='text/xsl' href='$xslt'?>";
        }
        push @xml, "<collection xmlns='" . $NAMESPACE . "'>";
    }
    print { $self->{filehandle} } join("\n",@xml)."\n" if @xml;
    $self->{in_doc} = 1;
    $self;
}

=head2 end_document ( )

Write XML footer (collection end element).
Note that this method does close the file handle if you write to a file.

=cut

sub end_document {
    my $self = shift;
    print { $self->{filehandle} } "</collection>\n" if $self->{filehandle} and $self->{in_doc};
    $self->{in_doc} = 0;
}

1;

__END__

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007-2009 by Verbundzentrale Göttingen (VZG) and Jakob Voß

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.


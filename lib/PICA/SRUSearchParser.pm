package PICA::SRUSearchParser;

=head1 NAME

PICA::SRUSearchParser - Parse a SRU response in XML and extract PICA+ records.

=cut

use strict;

our $VERSION = "0.41";

use Carp qw(croak);
use PICA::XMLParser;

=head1 METHODS

=head2 new

Creates a new Parser. See L<PICA::Parser> for a description of 
parameters to define handlers (Field and Record).

=cut

sub new {
    my ($class, %params) = @_;
    $class = ref $class || $class;

    my $self = {
        xmlparser => PICA::XMLParser->new( %params ),

        char_data => "",              # not used yet
        in_record => 0,

        numberOfRecords => undef,     # not implemented yet
        resultSetId => undef,         # this is needed for large result
        nextRecordPosition => undef   # sets. not implemented yet.
    };

    $self->{sruparser} = XML::Parser->new(
       Handlers => {
          Start => sub {$self->_start_handler(@_)},
          End   => sub {$self->_end_handler(@_)},
          Char  => sub {$self->_char_handler(@_)}
          # TODO: Init and Final are never called. Do we need them?
       }
    );

    bless $self, $class;
    return $self;
}

=head2 parseResponse

Parse an SRU SearchRetrieve Response given as an XML string.

=cut

sub parseResponse {
    my ($self, $response) = @_;
    $self->{sruparser}->parse($response);
}

=head2 counter

Get the number of read records so far.

=cut

sub counter {
   my $self = shift; 
   return return $self->{xmlparser}->{read_counter};
}

=head2 empty

Get the number of empty records that have been read so far.
By default empty records are not passed to the record handler
but counted.

=cut

sub empty {
   my $self = shift; 
   return $self->{xmlparser}->empty;
}

=head2 size

Get the total number of records in the SRU result set.
The result set may be split into several chunks.

=cut

sub size {
    my $self = shift;
    return $self->{numberOfRecords};
}

=head2 resultSetId

Get the SRU resultSetId.

=cut

sub resultSetId {
    my $self = shift;
    return $self->{resultSetId};
}

=head1 PRIVATE HANDLERS

Do not directly call this methods!

=head2 _start_handler

SAX handler for XML start tag. On PICA+ records this calls 
the start handler of L<PICA::XMLParser>, outside of records
it parses the SRU response.

=cut

sub _start_handler {
    my ($self, $parser, $name, %attrs) = @_;
    if ($self->{in_record}) {
        $self->{xmlparser}->start_handler($parser, $name, %attrs);
    } else {
        $self->{char_data} = "";
        if ($name eq "srw:recordData") {
            $self->{in_record} = 1;
        }
    }
}

=head2 _end_handler

SAX handler for XML end tag. On PICA+ records this calls 
the end handler of L<PICA::XMLParser>.

=cut

sub _end_handler {
    my ($self, $parser, $name) = @_;

    if ($self->{in_record}) {
        if ($name eq "srw:recordData") {
            $self->{in_record} = 0;
        } else {
            $self->{xmlparser}->end_handler($parser, $name);
        }
    } else {
        if ($name eq "srw:numberOfRecords") {
            $self->{numberOfRecords} = $self->{char_data};
        } elsif ($name eq "srw:resultSetId") {
            $self->{resultSetId} = $self->{char_data};
        }
    }
}

=head2 _char_handler

SAX handler for XML character data. On PICA+ records this calls 
the character data handler of L<PICA::XMLParser>.

=cut

sub _char_handler {
    my ($self, $parser, $string) = @_;

    if ($self->{in_record}) {
        $self->{xmlparser}->char_handler($parser, $string);
    } else {
        $self->{char_data} .= $string;
    }
}

1;

=head1 TODO

There seems to be a memory leak in the new() method, try
while(1) { my $parser = PICA::SRUSearchParser->new(); }

A method to get the parameters in the header (numberOfRecords, resultSetId...)
is needed to get the number of records before actually parsing the result.

Following requests of next records it not implemented yet.

There is no check whether the SRU server supports pica format.

Better error handling would be nice to skip invalid records but parse the rest.

We need test cases.

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007-2009 by Verbundzentrale Göttingen (VZG) and Jakob Voß

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

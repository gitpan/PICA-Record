package PICA::XMLParser;

=head1 NAME

PICA::XMLParser - Parse PICA+ XML

=head1 SYNOPSIS

  my $rcount = 1;
  my $parser = PICA::XMLParser->new( 
      Field => \&field_handler,
      Record => \&record_handler
  );
  $parser->parsefile($filename);

  # equivalent:
  PICA::Parser->parsefile($filename,
      Field => \&field_handler,
      Record => \&record_handler,
      Format => 'xml'  
  );

  sub field_handler {
      my $field = shift;
      print $field->to_string();
      # no need to save the field so do not return it
  }

  sub record_handler {
      print "$rcount\n"; $rcount++;
  }

=head1 DESCRIPTION

This module contains a parser to parse PICA+ XML. Up to now
PICA+ XML is not fully standarized yet so this parser may 
slightly change in the future.

=cut

use strict;
use warnings;

use PICA::Field;
use PICA::Record;

require XML::Parser;

use Carp;

use vars qw($VERSION);
$VERSION = "0.35";

=head1 PUBLIC METHODS

=head2 new

Creates a new Parser. See L<PICA::Parser> for a description of 
parameters to define handlers (Field and Record).

=cut

sub new {
    my ($class, %params) = @_;
    $class = ref $class || $class;

    my $self = {
        collection => {},
        record => {},
        fields => {},

        tag => "",
        occurrence => "",
        subfield_code => "",
        subfield_value => "",
        filename => "",

        # Handlers
        field_handler  => $params{Field} ? $params{Field} : undef,
        record_handler => $params{Record} ? $params{Record} : undef,
        collection_handler => $params{Collection} ? $params{Collection} : undef,

        proceed => $params{Proceed} ? $params{Proceed} : 0,

        read_counter => 0,
        empty => 0
    };
    bless $self, $class;
    return $self;
}

=head2 parsedata

Parses data from a string, array reference or function. 
Data from arrays and functions will be read and buffered 
before parsing. Do not directly call this method without 
a C<PICA::XMLParser> object that was created with C<new()>.

=cut

sub parsedata {
    my ($self, $data) = @_;

    if ( ! $self->{proceed} ) {
        $self->{read_counter} = 0;
        $self->{empty} = 0;
    }

    if ( ref($data) eq 'PICA::Record' ) {
        # TODO
    }

    my $parser = new XML::Parser(
        Handlers => $self->_getHandlers
    );

    if (ref($data) eq 'ARRAY') {
       $data = join('',@{$data})
    } elsif (ref($data) eq 'CODE') {
        my $code = $data;
        $data = "";
        my $chunk = &$code();
        while(defined $chunk) {
            $data .= $chunk;
            $chunk = &$code();
        }
    }

    $parser->parse($data);
}

=head2 parsefile (data)

Parses data from a file or filehandle.

=cut

sub parsefile {
    my ($self, $file) = @_;

    if ( ! $self->{proceed} ) {
        $self->{read_counter} = 0;
        $self->{empty} = 0;
    }

    $self->{filename} = $file if ref(\$file) eq 'SCALAR';
    my $parser = new XML::Parser(
        Handlers => $self->_getHandlers
    );

    if (ref($file) eq 'GLOB') {
    	$parser->parse($file);
    } else {
        $parser->parsefile($file);
    }
}

=head2 counter

Get the number of read records so far.

=cut

sub counter {
   my $self = shift; 
   return $self->{read_counter};
}

=head2 empty

Get the number of empty records that have been read so far.
By default empty records are not passed to the record handler
but counted.

=cut

sub empty {
   my $self = shift; 
   return $self->{empty};
}

=head1 PRIVATE HANDLERS

Do not directly call this methods.

=head2 init_handler

Called at the beginning.

=cut

sub init_handler {
  my ($self, $parser) = @_;

  $self->{subfield_code} = "";
  $self->{tag} = "";
  $self->{occurrence} = "";
  $self->{record} = ();
  $self->{collection} = ();
}

=head2 final_handler

Called at the end. Does nothing so far.

=cut

sub final_handler {
  # my ($self, $parser) = @_;
}

=head2 start_handler

Called for each start tag.

=cut

sub start_handler {
    my ($self, $parser, $name, %attrs) = @_;

    if ($name eq "subfield") {

        my $code = $attrs{"code"};
        if (defined $code) {
            if ($code =~ PICA::Field::SUBFIELD_CODE_REGEXP) {
                $self->{subfield_code} = $code;
                $self->{subfield_value} = "";
            } else {
               croak("Invalid subfield code '$code'" . $self->_getPosition($parser));
            }
        } else {
            croak("Missing attribute 'code'" . $self->_getPosition($parser));
        }
    } elsif ($name eq "field" or $name eq "datafield") {
        my $tag = $attrs{tag};
        if (defined $tag) {
            if (!($tag =~ PICA::Field::FIELD_TAG_REGEXP)) {
                croak("Invalid field tag '$tag'" . $self->_getPosition($parser));
            }
        } else {
            croak("Missing attribute 'tag'" . $self->_getPosition($parser));
        }
        my $occurrence = $attrs{occurrence};
        if ($occurrence && !($occurrence =~ PICA::Field::FIELD_OCCURRENCE_REGEXP)) {
            croak("Invalid occurrence '$occurrence'" . $self->_getPosition($parser));
        }

        $self->{tag} = $tag;
        $self->{occurrence} = $occurrence ? $occurrence : undef;
        $self->{subfields} = ();

    } elsif ($name eq "record") {
        $self->{fields} = [];
    } elsif ($name eq "collection") {
        $self->{records} = [];
    } else {
        croak("Unknown element '$name'" . $self->_getPosition($parser));
    }
}

=head2 end_handler

Called for each end tag.

=cut

sub end_handler {
    my ($self, $parser, $name) = @_;

    if ($name eq "subfield") {
        push (@{$self->{subfields}}, ($self->{subfield_code}, $self->{subfield_value}));
    } elsif ($name eq "field" or $name eq "datafield") {

        croak ("Field " . $self->{tag} . " is empty" . $self->_getPosition($parser)) unless $self->{subfields};

        my $field = bless {
            _tag => $self->{tag},
            _occurrence => $self->{occurrence},
            _subfields => [@{$self->{subfields}}]
        }, 'PICA::Field';

        if ($self->{field_handler}) {
            $field = $self->{field_handler}( $field );
        }

        if (UNIVERSAL::isa($field,"PICA::Field")) {
            push (@{$self->{fields}}, $field);
        }
    } elsif ($name eq "record") {

        my $record = bless {
            _fields => [@{$self->{fields}}]
        }, 'PICA::Record';

        if ($self->{record_handler}) {
            $record = $self->{record_handler}( $record );
        }

         $self->{read_counter}++;
         # if ( $record->is_empty() ) {
         #   $self->{empty}++;
            # TODO: Test whether empty records should be skipped
         #}
         # TODO: add to collection

    } elsif ($name eq "collection") {
      # TODO
    } else {
        croak("Unknown element '$name'" . $self->_getPosition($parser));
    }
}

=head2 char_handler

Called for character data.

=cut

sub char_handler {
    my ($self, $parser, $string) = @_;

    # all character data outside of subfield content will be ignored without warning
    if (defined $self->{subfield_code}) {
        $string =~ s/[\n\r]+/ /g; # remove newlines
        $self->{subfield_value} .= $string;
    }
}

=head2 _getHandlers

Get the handlers (init_handler, final_handler, start_handler, end_handler, char_handler).

=cut


sub _getHandlers {
    my $self = shift;
    my %handlers = (
        Init  => sub {$self->init_handler(@_)},
        Final => sub {$self->final_handler(@_)},
        Start => sub {$self->start_handler(@_)},
        End   => sub {$self->end_handler(@_)},
        Char  => sub {$self->char_handler(@_)}
    );
    return \%handlers;
}

=head2 _getPosition

Get the current position (file name and line number).

=cut

sub _getPosition {
    my ($self, $parser) = @_;

    if ($self->{filename}) {
        return " in " . $self->{filename} . ", line " . $parser->current_line();
    } else {
        return " in line " . $parser->current_line();
    }
}

1;

__END__

=head1 TODO

XML namespaces are not supported yet. When XML errors occur, there 
should be better error messages that point to a give file and line.
Return values of collections are not supported yet.

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007 by Verbundzentrale Goettingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.


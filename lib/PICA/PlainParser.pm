package PICA::PlainParser;

=head1 NAME

PICA::PlainParser - Parse normalized PICA+

=head1 SYNOPSIS

  my $parser = PICA::PlainParser->new(
      Field => \&field_handler,
      Record => \&record_handler
  );

  $parser->parsefile($filename);

  sub field_handler {
      my $field = shift;
      print $field->to_string();
      # no need to save the field so do not return it
  }

  sub record_handler {
      print "\n";
  }

=head1 DESCRIPTION

This module contains a parser for normalized PICA+

=cut

use strict;
use warnings;

use PICA::Field;
use PICA::Record;

use Carp;

use vars qw($VERSION);
$VERSION = "0.31";

=head1 PUBLIC METHODS

=head2 new (params)

Create a new parser. See L<PICA::Parser> for a detailed description of
the possible parameters C<Field>, C<Record>, and C<Collection>. Additionally
you may specify the parameter C<EmptyRecords> to define that empty records
will not be skipped but passed to the record handler and C<Strict> to abort
when an error occured. Default behaviour is not strict: errors are reported
to STDERR.

=cut

sub new {
    my ($class, %params) = @_;
    $class = ref $class || $class;

    my $self = {
        filename => "",

        field_handler  => $params{Field} ? $params{Field} : undef,
        record_handler => $params{Record} ? $params{Record} : undef,
        collection_handler => $params{Collection} ? $params{Collection} : undef,
        keep_empty_records => $params{EmptyRecords},

        record => undef,

        lax => $params{lax} ? $params{lax} : 1,
        strict_mode => $params{Strict},

        fields => [],

        read_counter => 0,
        empty => 0,
        active => 0,
    };
    bless $self, $class;
    return $self;
}

=head2 parsefile

Parses a file, specified by a filename or file handle. Additional possible 
parameters are handlers (C<Field>, C<Record>, C<Collection>) and options 
(C<Strict>, C<EmptyRecords>). If you supply a filename with extension
C<.gz> then it is extracted while reading with C<zcat>.

=cut

sub parsefile {
    my ($self, $arg) = @_;

    my $ishandle = do { no strict; defined fileno($arg); };
    if ($ishandle) {
        $self->{filename} = scalar( $arg );
        $self->{filehandle} = $arg;
    } else {
        $self->{filename} = $arg;

        my $fh = $arg;
        $fh = "zcat $fh|" if $fh =~ /\.gz$/;

        $self->{filehandle} = eval { local *FH; open( FH, $fh ) or die; *FH{IO}; };
        if ( $@ ) {
            croak("Error opening file '$arg'");
        }
    }

    $self->{read_counter} = 0;
    $self->{empty} = 0;
    $self->{active} = 0;
    $self->{record} = undef;
    while (my $line = readline( $self->{filehandle} ) ) {
        $self->_parseline($line);
    }
    $self->handle_record(); # handle last record
}

=head2 parsedata

Parses PICA+ data from a string, array or function. If you supply
a function then this function is must return scalars or arrays and
it is called unless it returns undef.

=cut

sub parsedata {
    my ($self, $data) = @_;

    $self->{read_counter} = 0;
    $self->{empty} = 0;
    $self->{active} = 0;
    $self->{record} = undef;

    if ( ref($data) eq 'CODE' ) {
        my $chunk = &$data();
        while(defined $chunk) {
            $self->_parsedata($chunk);
            $chunk = &$data();
        }
    } else {
        $self->_parsedata($data);
    }

    $self->handle_record(); # handle last record
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

=head1 PRIVATE METHODS

=head2 _parsedata

Parses a string or an array reference.

=cut

sub _parsedata {
    my ($self, $data) = @_;

    my @lines;

    if (ref(\$data) eq 'SCALAR') {
        @lines = split "\n", $data;
    } elsif (ref($data) eq 'ARRAY') {
        @lines = @{$data};
    } else {
        croak("Got " . ref(\$data) . " when parsing PICA+ while expecting SCALAR or ARRAY");
    }

    foreach my $line (@lines) {
        $self->_parseline($line);
    }
}

=head2 _parseline

Parses a line (without trailing newline character). May throw an exception with croak.

=cut

sub _parseline {
    my ($self, $line) = @_;
    chomp $line; # remove newline if present

    # start of record marker
    if ( $line eq "\x1D" or ($self->{lax} and $line =~ /^\s*$/) ) {
        $self->handle_record() if $self->{active};
    } elsif( $self->{lax} and ($line =~ /^[#\[]/ or $line =~ /^SET:/)) {
        # ignore comments and lines starting with "SET" or "[" (WinIBW output)
    } else {
      my $field;
      eval {
          $field = PICA::Field->parse($line);
      };
      # error parsing a field (TODO: call error handler)
      if($@) {
          $@ =~ s/ at .*\n//;
          my $msg = "$@ Tried to parse line: \"$line\"\n";
          croak($msg) if $self->{strict_mode};
          print STDERR $msg;
      } else {
        if ($self->{field_handler}) {
            $field = $self->{field_handler}( $field );
        }

        if (UNIVERSAL::isa($field,'PICA::Field')) {
            push (@{$self->{fields}}, $field);
        }
      }
    }
    $self->{active} = 1;
}

=head2 handle_record

Calls the record handler.

=cut

sub handle_record {
    my $self = shift;

    $self->{read_counter}++;
 
    my $record = bless {
        _fields => [@{$self->{fields}}]
    }, 'PICA::Record';

    if ( $record->is_empty() ) {
        $self->{empty}++;
        if (!$self->{keep_empty_records}) {
            $self->{fields} = [];
            return;
        }
    }

    if ($self->{record_handler}) {
        $record = $self->{record_handler}( $record );
    }

    # TODO: save record if needed for collection handler

    $self->{fields} = [];
}

1;

__END__

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007 by Verbundzentrale Goettingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.


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
$VERSION = "0.39";

=head1 PUBLIC METHODS

=head2 new (params)

Create a new parser. See L<PICA::Parser> for a detailed description of
the possible parameters C<Field>, C<Record>, and C<Collection>. Errors
are reported to STDERR.

=cut

sub new {
    my ($class, %params) = @_;
    $class = ref $class || $class;

    my $self = bless {
        filename => "",

        field_handler  => defined $params{Field} ? $params{Field} : undef,
        record_handler => defined $params{Record} ? $params{Record} : undef,
        proceed => $params{Proceed} ? $params{Proceed} : 0,
        limit  => ($params{Limit} || 0) * 1,
        offset  => ($params{Offset} || 0) * 1,

        record => undef,
        read_records => [],

        dumpformat => $params{Dumpformat},
        lax => $params{lax} ? $params{lax} : 1,

        fields => [],

        read_counter => 0,
        active => 0,

    }, $class;

    return $self;
}

=head2 parsefile ( $file-or-handle [, options] )

Parses a file, specified by a filename or file handle. Additional possible 
parameters are handlers (C<Field>, C<Record>, C<Collection>) and options 
(C<EmptyRecords>). If you supply a filename with extension
C<.gz> then it is extracted while reading with C<zcat>, if the extension 
is C<.zip> then C<unzip> is used to extract. 

This method temporarily changes the end-of-line character if parsing in
dumpformat is requested.

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
        $fh = "zcat $fh |" if $fh =~ /\.gz$/;
        $fh = "unzip -p $fh |" if $fh =~ /\.zip$/;

        $self->{filehandle} = eval { local *FH; open( FH, $fh ) or die; *FH{IO}; };
        if ( $@ ) {
            croak("Error opening file '$arg'");
        }
    }

    if ( ! $self->{proceed} ) {
        $self->{read_counter} = 0;
        $self->{read_records} = [];
    }

    $self->{active} = 0;
    $self->{record} = undef;

    # dumpformat used \x1E instead of newlines
    if ($self->{dumpformat}) {
        my $EOL = $/;
        $/ = chr(0x1E);
        my $id = "";

        while (my $line = readline( $self->{filehandle} )) {
            last if ($self->finished());

            $line =~ /^\x1D?([^\s]+)/;
            if (PICA::Field::parse_pp_tag($1)) {
                $self->_parseline($line);
            } else {
                if ( !defined $id or "$id" ne "$1" ) { 
                    $self->_parseline("");
                }
                $id = $1;
            }
        }

        $/ = $EOL;
    } else {
        while (my $line = readline( $self->{filehandle} )) {
            last if ($self->finished());

            $self->_parseline($line);
        }
    }

    $self->handle_record() unless $self->finished(); # handle last record

    $self;
}

=head2 parsedata ( $data )

Parses PICA+ data from a string, array or function. If you supply
a function then this function is must return scalars or arrays and
it is called unless it returns undef.

=cut

sub parsedata {
    my ($self, $data, $additional) = @_;

    $self->{active} = 0;
    $self->{record} = undef;

    if ( ! $self->{proceed} ) {
        $self->{read_counter} = 0;
        $self->{read_records} = [];
    }

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

    $self;
}


=head2 records ( )

Get an array of the read records (if they have been stored)

=cut

sub records {
   my $self = shift; 
   return @{ $self->{read_records} };
}

=head2 counter ( )

Get the number of read records so far. Please note that the number
of records as returned by the C<records> method may be lower because
you may have filtered out some records.

=cut

sub counter {
   my $self = shift; 
   return $self->{read_counter};
}

=head2 finished ( )

Return whether the parser will not parse any more records. This
is the case if the number of read records is larger then the limit.

=cut

sub finished {
    my $self = shift; 
    return $self->{limit} && $self->counter() >= $self->{limit};
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
        # ignore non-data fields
        # TODO: be more specific here
    } else {
      my $field;
      eval {
          $field = PICA::Field->parse($line);
      };
      # error parsing a field
      if($@) {
          $@ =~ s/ at .*\n//;
          my $msg = "$@ Tried to parse line: \"$line\"\n";
          # TODO: pass this to an error handler that may abort parsing
          # croak($msg);
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

    $self->{fields} = [];

    return if ($self->{offset} && $self->{read_counter} < $self->{offset});

    if ($self->{record_handler}) {
        $record = $self->{record_handler}( $record );
    }
    if ($record) {
        push @{ $self->{read_records} }, $record;
    }
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


package PICA::Writer;

=head1 NAME

PICA::Writer - Write and count PICA+ records and fields

=cut

=head1 SYNOPSIS

  my $writer = PICA::Writer->new(\*STDOUT);

  $writer->write( $record );
  $writer->write( $comment, $record );

  print $writer->counter() . " records, " . $writer->fields() . " fields\n";

  $writer->writefield( $field );
  $writer->reset();

=head1 DESCRIPTION

This module contains a simple class to write and count PICA+ records and fields
(printing of single fields may not be possible in all implementations).

=cut

use strict;
use warnings;

use PICA::Record;
use utf8;
use Carp;

use vars qw($VERSION);
$VERSION = "0.31";

=head1 PUBLIC METHODS

=head2 new (file-or-handle)

Create a new parser. Needs a reference to a file handle or a file 
name. If no parameter is specified then the writer will not write 
but count only.

=cut

sub new {
    my ($class) = shift;
    $class = ref $class || $class;

    my $self = {
        recordcounter => 0,
        fieldcounter => 0,
        filehandle => undef
    };
    bless $self, $class;

    $self->reset(@_);

    return $self;
}

=head2 reset

Reset the writer by setting the counters to zero. 
You may also specify a new file handler or file name.

=cut

sub reset {
    my $self = shift;
    my $arg = shift;

    $self->{recordcounter} = 0;
    $self->{fieldcounter} = 0;

    $self->reset_handler($arg) if $arg;
}

=head2 reset_handler

Reset the file handler or file name without resetting the counters.

=cut

sub reset_handler {
    my $self = shift;
    my $arg = shift;

    my $ishandle = do { no strict; defined fileno($arg); };
    if ($ishandle) {
        $self->{filename} = "";
        $self->{filehandle} = $arg;
    } else {
        $self->{filename} = $arg;
        $self->{filehandle} = eval { local *FH; open( FH, ">$arg" ) or die; binmode FH, ":utf8"; *FH{IO}; };
        if ( $@ ) {
            croak("Failed to open file for writing: $arg");
        }
    }
}

=head2 write

Write a record(s) of type L<PICA::Record>. You may specify strings before a record
that will be used as a comment:

  $writer->write( $record );
  $writer->write( @records );
  $writer->write( "Record number: $counter", $record );

=cut

sub write {
    my $self = shift;

    my $comment = "";
    while (@_) {
        my $record = shift;

        if (ref($record) eq 'PICA::Record') {
            print { $self->{filehandle} } $record->normalized($comment) if $self->{filehandle};
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

=head2 writefield

Write one ore more C<PICA::Field>. Please be aware that the output will not 
be wellformed PICA+ if you have not written a start record marker before!

=cut

sub writefield {
    my $self = shift;
    while (@_) {
        my $field = shift;
            if (ref($field) ne 'PICA::Field') {
                croak("Cannot write object of unknown type (PICA::Field expected)!");
            } else {
                print { $self->{filehandle} } $field->normalized() if $self->{filehandle};
                $self->{fieldcounter}++;
            }
	}
}

=head2 counter

Returns the number of written records.

=cut

sub counter {
    my $self = shift;
    return $self->{recordcounter};
}

=head2 fields

Returns the number of written fields.

=cut

sub fields {
    my $self = shift;
    return $self->{fieldcounter};
}

=head2 name

Returns the name of the writer (usually the filename) if defined.

=cut

sub name {
    my $self = shift;
    return $self->{filename};
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



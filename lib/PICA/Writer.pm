package PICA::Writer;

=head1 NAME

PICA::Writer - Write and count PICA+ records and fields

=cut

=head1 SYNOPSIS

  my $writer = PICA::Writer->new( \*STDOUT );

  $writer->write( $record );
  $writer->write( $comment, $record );

  print $writer->counter() . " records, " . $writer->fields() . " fields\n";

  $writer->writefield( $field );
  $writer->reset();

  $writer = PICA::Writer->new( \*STDOUT, format => 'xml' );
  $writer = PICA::Writer->new( \*STDOUT, format => 'plain' );

=head1 DESCRIPTION

This module contains a simple class to write and count PICA+ records and fields
(printing of single fields may not be possible in all implementations).

=cut

use strict;
use warnings;

use PICA::Record;
use PICA::XMLWriter;
use utf8;
use Carp;

use vars qw($VERSION);
$VERSION = "0.35";

=head1 METHODS

=head2 new ( [ <file-or-handle> ] [, %parameters ] )

Create a new parser. You can path a reference to a handle or
a file name and additional parameters. If file or handle is specified 
then the writer will not write but count records. The only parameter
so far is C<format> (with value C<xml>, C<normalized>, or C<plain>).

=cut

sub new {
    my $class = shift;
    my ($fh, %param) = @_ % 2 ? @_ : (undef, @_);

    if (defined $param{format}) {
        return PICA::XMLWriter->new( @_ ) if $param{format} =~ /^xml$/i;
    }

    my $self = bless { 
        'format' => $param{format} || "plain"
    }, $class;
    return $self->reset($fh);
}

=head2 reset ( [ $filename | $handle ] )

Reset the writer by setting the counters to zero.
You may also specify a new handle or file name. 
This methods returns the writer itself.

=cut

sub reset {
    my $self = shift;
    my $fh = shift;

    $self->{recordcounter} = 0;
    $self->{fieldcounter} = 0;

    if ($fh) {
        $self->reset_handler($fh);
    } else {
        $self->{filehandle} = undef;
    }

    $self;
}

=head2 reset_handler

Reset the file handler or file name without resetting the counters.

=cut

sub reset_handler {
    my $self = shift;
    my $fh = shift;

    my $ishandle = do { no strict; defined fileno($fh); };
    if ($ishandle) {
        $self->{filename} = "";
        $self->{filehandle} = $fh;
    } else {
        $self->{filename} = $fh;
        $self->{filehandle} = eval { local *FH; open( FH, ">$fh" ) or die; binmode FH, ":utf8"; *FH{IO}; };
        if ( $@ ) {
            croak("Failed to open file for writing: $fh");
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
            my $str = $self->{format} eq 'plain' ?
                $record->to_string() :
                $record->normalized($comment);
            print { $self->{filehandle} } $str if $self->{filehandle};
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
                my $str = $self->{format} eq 'plain' ?
                    $field->to_string() :
                    $field->normalized();
                print { $self->{filehandle} } $str if $self->{filehandle};
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



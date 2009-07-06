package PICA::Writer;

=head1 NAME

PICA::Writer - Write and count PICA+ records and fields

=cut

use strict;
use utf8;
our $VERSION = "0.48";

=head1 DESCRIPTION

This module contains a simple class to write PICA+ records and fields.
Several output targets (file, GLOB, L<IO:Handle>, string) and formats 
(XML, plain, normalized) are supported. The number of written records
and fields is counted so you can also use the class as a simple counter.

=head1 SYNOPSIS

  $writer = PICA::Writer->new( \*STDOUT );
  $writer = PICA::Writer->new( "output.pica" );
  $writer = PICA::Writer->new( \$string, format => 'xml' );
  $writer = PICA::Writer->new( ); # no output

  $writer->start();  # called implicitely by default

  $writer->write( $record );
  $writer->write( $field1, $field2, $field3 );
  $writer->write( $comment, $record );

  $writer->output( "output.xml" );  
  $writer->output( \*STDOUT, format => 'plain' );  

  print $writer->counter() . " records written\n";
  print $writer->fields()  . " fields written\n";

  $writer->reset();  # reset counters

  print $writer->status() == PICA::Writer::ENDED ? "open" : "ended";
 
  $writer->end(); # essential to close end tags in XML and such

=cut

use PICA::Record;
use XML::Writer;
use IO::Handle;
use IO::Scalar;
use IO::File;
use Carp qw(croak);

use constant NEW     => 0;
use constant STARTED => 1;
use constant ENDED   => 2;

=head1 METHODS

=head2 new ( [ $output ] [ format => $format ] [ %options ] )

Create a new writer. See the output method for possible parameters. 
The status of the new writer is set to PICA::Writer::NEW which is zero.

=cut

sub new {
    my $class = shift;
    my $self = bless {
        status => NEW,
        io => undef,
        options => {},
        recordcounter => 0,
        fieldcounter => 0
    }, $class;
    return $self->reset( @_ ? @_ : undef );
}

=head2 output ( [ $output ] [ format => $format ] [ %options ] )

Define the output handler for this writer. Record and field counters are
not reset but the writer is ended with the end method if it had been 
started before. The output handler can be a filename, a GLOB, an
L<IO:Handle> object, a string reference, or undef. In addition you
can specify the output format with the format parameter (plain or xml)
and some options depending on the format - for instance 'pretty => 1'.

The status of the writer is set to PICA::Writer::NEW which is zero.

=cut

sub output {
    my $self = shift;
    my ($output, %options) = @_ % 2 ? @_ : (undef, @_);

    %{ $self->{options} } = %options;
    my $format = $self->{options}->{format};

    if (not defined $output) {
        $self->{io} = undef;
    } elsif ( ref($output) eq 'GLOB' ) {
        $self->{io} = $output;
        #binmode $self->{io}, ":utf8";
    } elsif (UNIVERSAL::isa('IO::Handle', $output)) {
        $self->{io} = $output;
    } elsif ( ref($output) eq 'SCALAR' ) {
        $self->{io} = IO::Scalar->new( $output );
    } else {
        $self->{io} = IO::File->new($output, '>:utf8');
        $format = 'xml' unless defined $format and $output =~ /\.xml$/;
    }

    if ($options{pretty}) {
        $options{DATA_MODE} = 1;
        $options{DATA_INDENT} = 2;
        $options{NAMESPACES} = 1;
        $options{PREFIX_MAP} =  {'info:srw/schema/5/picaXML-v1.0'=>''};
    }

    $format = 'plain' unless defined $format and $format =~ /^(plain|normalized|xml)$/i;
    $self->{options}->{format} = lc($format);
    if ( $format =~ /^xml$/i and defined $output ) {
        $options{OUTPUT} = $self->{io};
        $options{header} = 1 unless defined $options{header};
        $self->{xmlwriter} = PICA::Writer::xmlwriter( %options );
    } else {
        $self->{xmlwriter} = undef;
    }
    
    return $self;
}

=head2 reset ( [ $output ] )

Reset the writer by setting record and field counters to zero and returning
the writer object. Optionally you can define a new output handler, so the 
following two lines are equal:

  $writer->output( $output )->reset();
  $writer->reset( $output );

The status of the writer will only be changed if you specify a new output handler.

=cut

sub reset {
    my $self = shift;
    $self->output( @_ ) if @_;

    $self->{recordcounter} = 0;
    $self->{fieldcounter} = 0;

    return $self;
}

=head2 write ( [ $comment | $record | $field ]* )

Write L<PICA::Field>, L<PICA::Record> objects, and comments (as strings)
and record the writer object. The number of written records and fields is
counted and can be queried with methods counter and fields.

  $writer->write( $record );
  $writer->write( @records );
  $writer->write( "record number " . $writer->counter(), $record );
  $writer->write( $field1, $field2 );

Writing single fields or mixing records and fields may not be possible 
depending on the output format and output handler. 

=cut

sub write {
    my $self = shift;
    croak('cannot write to a closed writer') if $self->status() == ENDED;
    $self->start() if $self->status() != STARTED;

    my $format = $self->{options}->{format};

    if (UNIVERSAL::isa($_[0],'PICA::Field')) {
        while (@_) {
            my $field = shift;
            if (UNIVERSAL::isa($field,'PICA::Field')) {
                if ($format eq 'plain') {
                    print { $self->{io} } $field->to_string() if $self->{io};
                } elsif ($format eq 'normalized') {
                    print { $self->{io} } $field->normalized() if $self->{io};
                } elsif ($format eq 'xml' and defined $self->{xmlwriter} ) {
                    $field->write_xml( $self->{xmlwriter} );
                }
                $self->{fieldcounter}++;
            } else {
                croak("Cannot write object of unknown type (PICA::Field expected)!");
            }
        }
    } else {
        my $comment = "";
        while (@_) {
            my $record = shift;
            if ( UNIVERSAL::isa($record, 'PICA::Record') ) {
                if ($format eq 'plain') {
                    print { $self->{io} } "\n"
                        if ($self->{recordcounter} > 0 && $self->{io});
                    print { $self->{io} } $record->to_string() if $self->{io};
                } elsif ($format eq 'normalized') {
                    print { $self->{io} }  "\x1D\x0A"
                        if ($self->{recordcounter} > 0 && $self->{io});
                    print { $self->{io} } $record->normalized() if $self->{io};
                } elsif ($format eq 'xml' and defined $self->{xmlwriter} ) {
                    $record->write_xml( $self->{xmlwriter} );
                }
                $self->{recordcounter}++;
                $self->{fieldcounter} += scalar $record->all_fields;
            } elsif (ref(\$record) eq 'SCALAR') {
                next if !$record;
                $comment = '# ' . join("\n# ", split(/\n/,$record)) . "\n";
                $comment =~ s/--//g;
                if ($format eq 'xml') {
                    $self->{xmlwriter}->comment( $comment )
                        if defined $self->{xmlwriter};
                } else {
                    print { $self->{io} } $comment if $self->{io};
                }
            } else {
                croak("Cannot write object of unknown type (PICA::Record expected)!");
            }
        }
    }

    return $self;
}

=head2 start ( [ %options ] )

Start writing and return the writer object. Depending on the format and 
output handler a header is written. Afterwards the status is set to
PICA::Writer::STARTED. You can pass optional parameters depending on the
format.

  $writer->start( ); # default
  $writer->start( xslt => 'mystylesheet.xsl' );
  $writer->start( nsprefix => 'pica' );

This method is implicitely called the first time you write to a PICA::Writer
that is not in status PICA::Writer::STARTED..

=cut

sub start {
    my $self = shift;
    croak('cannot start a writer twice') if $self->status() == STARTED;

    my $writer = $self->{xmlwriter};
    if ( $self->{options}->{format} eq 'xml' and defined $writer ) {
        if (UNIVERSAL::isa( $writer, 'XML::Writer::Namespaces' )) {
            $writer->startTag( [$PICA::Record::XMLNAMESPACE, 'collection'] );
        } else {
            $writer->startTag( 'collection' );
        }
    }

    $self->{status} = STARTED;

    return $self;
}


=head2 end ( )

Finish writing. Depending on the format and output handler a footer is
written (for instance an XML end tag) and the output handler is closed. 
Afterwards the status is set to PICA::Writer::ENDED. If the writer had
not been started before, the start method is called first. 

Ending or writing to an already ended writer will throw an error. You can
restart an ended writer with the output method or with the start method.

=cut

sub end {
    my $self = shift;
    croak('cannot end a writer twice') if $self->status() == ENDED;
    $self->start() if $self->status() != STARTED;

    if ( $self->{options}->{format} eq 'xml') {
        if ( defined $self->{xmlwriter} ) {
            $self->{xmlwriter}->endTag(); # </collection>
            $self->{xmlwriter}->end(); 
        }
    } else {
        # other supported formats don't need end handling
    }

    $self->{io}->close if defined $self->{io};
    $self->{status} = ENDED;
 
    return $self;
}

=head2 status ( )

Return the status which can be PICA::Writer::NEW (0),
PICA::Writer::STARTED, or PICA::Writer::ENDED.

=cut

sub status {
    my $self = shift;
    return $self->{status};
}

=head2 counter ( )

Returns the number of written records.

=cut

sub counter {
    my $self = shift;
    return $self->{recordcounter};
}

=head2 fields ( )

Returns the number of written fields.

=cut

sub fields {
    my $self = shift;
    return $self->{fieldcounter};
}

=head1 FUNCTIONS

=head2 xmlwriter ( %params )

Create a new L<XML::Writer> instance and optionally write XML header
and processing instruction. Relevant parameters include 'header' (boolean),
'xslt', NAMESPACES, PREFIX_MAP.

=cut

sub xmlwriter {
    my %params = @_;

    $params{NAMESPACES} = 1 unless defined $params{NAMESPACES};
    if (not defined $params{PREFIX_MAP} or 
        not defined $params{PREFIX_MAP}->{ $PICA::Record::XMLNAMESPACE }) {
        $params{PREFIX_MAP} = { $PICA::Record::XMLNAMESPACE => 'pica'};
    }
    my $writer = XML::Writer->new( %params );
    $writer->xmlDecl('UTF-8') if $params{header};
    if ($params{xslt}) {
        $writer->pi('xml-stylesheet', 'type="text/xsl" href="' . $params{xslt} . '"');
    }

    return $writer;
}

1;

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007-2009 by Verbundzentrale Göttingen (VZG) and Jakob Voß

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

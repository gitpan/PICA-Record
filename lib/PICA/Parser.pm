package PICA::Parser;

=head1 NAME

PICA::Parser - Parse PICA+ data

=head1 SYNOPSIS

  use PICA::Parser;

  PICA::Parser->parsefile( $filename_or_handle ,
      Field => \&field_handler,
      Record => \&record_handler
  );

  PICA::Parser->parsedata( $string_or_function ,
      Field => \&field_handler,
      Record => \&record_handler
  );

  $parser = PICA::Parser->new(
      Record => \&record_handler,
      Proceed => 1
  );
  $parser->parsefile( $filename );
  $parser->parsedata( $picadata );
  print $parser->counter() . " records read.\n";

You can also export C<parsedata> and C<parsefile>:

  use PICA::Parser qw(parsefile);

  parsefile( $filename, Record => sub {
      my $record = shift;
      print $record->to_string() . "\n";
  });

Both function return the parser, so you can use
constructs like

  my @records = parsefile($filename)->records();

=head1 DESCRIPTION

This module can be used to parse normalized PICA+ and PICA+ XML.
The conrete parsers are implemented in L<PICA::PlainParser> and 
L<PICA::XMLParser>.

=cut

use strict;
use warnings;

use Carp;

use vars qw($VERSION @ISA @EXPORT_OK);
$VERSION = "0.39";

@ISA = qw(Exporter);
@EXPORT_OK = qw(parsefile parsedata);

=head1 CONSTRUCTOR

=head2 new ( [ %params ] )

Creates a Parser to store common parameters (see below). These 
parameters will be used as default when calling C<parsefile> or
C<parsedata>. Note that you do not have to use the constructor to 
use C<PICA::Parser>. These two methods do the same:

  my $parser = PICA::Parser->new( %params );
  $parser->parsefile( $file );

  PICA::Parser->parsefile( $file, %params );

Common parameters that are passed to the specific parser are:

=over

=item Field

Reference to a handler function for parsed PICA+ fields. 
The function is passed a L<PICA::Field> object and it should
return it back to the parser. You can use this function as a
simple filter by returning a modified field. If no 
L<PICA::Field> object is returned then it will be skipped.

=item Record

Reference to a handler function for parsed PICA+ records. The
function is passed a L<PICA::Record>. If the function returns
a record then this record will be stored in an array that is
passed to C<Collection>. You can use this method as a filter
by returning a modified record.

=item Error

This handler is used if an error occured while parsing, for instance
if data does not look like PICA+. By default errors are just ignored.

TODO: Count errors and return the number of errors in the C<errors> method.

=item Offset

Skip a given number of records. Default is zero.

=item Limit

Stop after a given number of records. Non positive numbers equal to unlimited.

=item Dumpformat

If set to true, parse dumpformat (no newlines).

=item Proceed

By default the internal counters are reset and all read records are
forgotten before each call of C<parsefile> and C<parsedata>. 
If you set the C<Proceed> parameter to a true value, the same parser
will be reused without reseting counters and read record.

=back

=cut

sub new {
    my $class = "PICA::Parser";
    if (scalar(@_) % 2) { # odd
        $class = shift;
        $class = ref $class || $class;
    }
    my %params = @_;

    my $self = bless {
        defaultparams => {},
        xmlparser => undef,
        plainparser => undef
    }, $class;

    %{ $self->{defaultparams} } = %params if %params;

    return $self;
}

=head1 METHODS

=head2 parsefile ( $filename-or-handle [, %params ] )

Parses pica data from a file, specified by a filename or filehandle.
The default parser is L<PICA::PlainParser>. If the filename extension 
is C<.xml> or C<.xml.gz> or the C<Format> parameter set to C<xml> then
L<PICA::XMLParser> is used instead. 

  PICA::Parser->parsefile( "data.picaplus", Field => \&field_handler );
  PICA::Parser->parsefile( \*STDIN, Field => \&field_handler, Format='XML' );
  PICA::Parser->parsefile( "data.xml", Record => sub { ... } );

See the constructor C<new> for a description of parameters.

=cut

sub parsefile {
    my $self = shift;
    my ($arg, $parser);

    if (ref($self) eq 'PICA::Parser') { # called as a method
        $arg = shift;
        my %params = @_;
        if (ref(\$arg) eq 'SCALAR' and ($arg =~ /.xml$/i or $arg =~ /.xml.gz$/i)) {
            $params{Format} = "XML";
        }
        $parser = $self->_getparser( %params );
        croak("Missing argument to parsefile") unless defined $arg;
        $parser->parsefile( $arg );
        $self;
    } else { # called as a function
        $arg = ($self eq 'PICA::Parser') ? shift : $self;
        $parser = PICA::Parser->new( @_ );
        croak("Missing argument to parsefile") unless defined $arg;
        $parser->parsefile( $arg );
        $parser;
    }
}

=head2 parsedata ( $data [, %params ] )

Parses data from a string, array reference, or function and returns
the C<PICA::Parser> that was used. See C<parsefile> and the C<parsedata>
method of L<PICA::PlainParser> and L<PICA::XMLParser> for a description
of parameters. By default L<PICA::PlainParser> is used unless there the
C<Format> parameter set to C<xml>.

  PICA::Parser->parsedata( $picastring, Field => \&field_handler );
  PICA::Parser->parsedata( \@picalines, Field => \&field_handler );

  # called as a function
  my @records = parsedata( $picastring )->records();

If data is a L<PICA::Record> object, it is directly passed to the 
record handler without re-parsing. See the constructor C<new> for 
a description of parameters.

=cut

sub parsedata {
    my $self = shift;
    my ( $data, $parser );

    if (ref($self) eq 'PICA::Parser') { # called as a method
        $data = shift;
        my %params = @_;
        $parser = $self->_getparser( %params );
        $parser->parsedata( $data );
        $self;
    } else { # called as a function
        $data = ($self eq 'PICA::Parser') ? shift : $self;
        $parser = PICA::Parser->new( @_ );
        $parser->parsedata( $data );
        $parser;
    }
}

=head2 records ( )

Get an array of the read records (as returned by the record handler which
can thus be used as a filter). If no record handler was specified, records
will be collected unmodified. For large record sets it is recommended not
to collect the records but directly use them with a record handler.

=cut

sub records {
    my $self = shift;
    return [] unless ref $self;

    return $self->{plainparser}->records() if $self->{plainparser};
    return $self->{xmlparser}->records() if $self->{xmlparser};

    return [];
}

=head2 counter ( )

Get the number of read records so far. Please note that the number
of records as returned by the C<records> method may be lower because
you may have filtered out some records.

=cut

sub counter {
    my $self = shift;
    return undef if !ref $self;

    my $counter = 0;
    $counter += $self->{plainparser}->counter() if $self->{plainparser};
    $counter += $self->{xmlparser}->counter() if $self->{xmlparser};
    return $counter;
}

=head1 INTERNAL METHODS

=head2 _getparser ( [ %params] )

Internal method to get a new parser of the internal parser of this object.
By default, gives a L<PICA:PlainParser> unless you specify the C<Format>
parameter. Single parameters override the default parameters specified at
the constructor (except the the C<Proceed> parameter).

=cut

sub _getparser {
    my $self = shift;
    my %params = @_;
    delete $params{Proceed} if defined $params{Proceed};

    my $parser;

    # join parameters
    my %unionparams = ();
    my %defaultparams = %{ $self->{defaultparams} };
    my $key;
    foreach $key (keys %defaultparams) {
        $unionparams{$key} = $defaultparams{$key}
    }
    foreach $key (keys %params) {
        $unionparams{$key} = $params{$key}
    }
    # remove format parameter
    delete $params{Format} if defined $params{Format};

    # XMLParser
    if ( defined $unionparams{Format} and $unionparams{Format} =~ /^xml$/i ) {
        if ( !$self->{xmlparser} or %params ) {
            require PICA::XMLParser; 
            #if ($self->{xmlparser} && 
            $self->{xmlparser} = PICA::XMLParser->new( %unionparams );
        }
        $parser = $self->{xmlparser};
    } else { # PlainParser
        if ( !$self->{plainparser} or %params ) {
            require PICA::PlainParser; 
            $self->{plainparser} = PICA::PlainParser->new( %unionparams );
        }
        $parser = $self->{plainparser};
    }

    return $parser;
}

1;

__END__

=head1 TODO

Better logging needs to be added, for instance a status message every n records.
This may be implemented with multiple (piped?) handlers per record. Error handling
of broken records should also be improved.

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007, 2008 by Verbundzentrale Goettingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

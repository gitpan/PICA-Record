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

=head1 DESCRIPTION

This module can be used to parse normalized PICA+ and PICA+ XML.
The conrete parsers are implemented in L<PICA::PlainParser> and 
L<PICA::XMLParser>.

=cut

use strict;
use warnings;

use Carp;

use vars qw($VERSION @ISA @EXPORT_OK);
$VERSION = "0.35";

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
passed to C<EndCollection>. You can use this method as a filter
by returning a modified record.

=item Collection

Alias for C<EndCollection>. Ignored if C<EndCollection> is specified.

=item StartCollection

Reference to a handler function that is called before a
collection of PICA+ record. Each file is treated as a
collection so this is called before parsing a file.

=item EndCollection

Reference to a handler function for parsed PICA+ collections.
An array of L<PICA::Record> objects is passed to the function.
For performace reasons it is recommended to directly use the
stream of records with the L<Record> handler instead of collecting
all storing records and using them afterwards. This parameter is 
not supported yet.

=item Error

This handler is used if an error occured while parsing, for instance
if data does not look like PICA+. By default errors are just ignored.

TODO: Count errors and return the number of errors in the C<errors> method.

=item Strict

Stop on errors. By default a parser just omits records that could
not been parsed. (default is false). Up to now strict_mode is only
available in L<PICA::PlainParser>!

=item EmptyRecords

Skip empty records so they will not be passed to the record handler
(default is false). Empty records easily occur for instance if your 
field handler does not return anything - this is useful for performance 
but you should not forget to set the EmptyRecords parameter. In every
case empty records are counted with a special counter that can be read 
with the C<empty> method. The normal counter (method C<counter>) 
counts all records no matter if empty or not.

=item Proceed

By default the internal counters are reset with each call of C<parsefile> 
and C<parsedata>. If you set the C<Proceed> parameter to a true value, 
the same parser will be reused without reseting. 

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
is C<.xml> or C<.xml.gz> or the 'Format' parameter set to 'xml' then
L<PICA::XMLParser> is used instead. 

  PICA::Parser->parsefile( "data.picaplus", Field => \&field_handler );
  PICA::Parser->parsefile( \*STDIN, Field => \&field_handler, Format='XML' );

See the constructor C<new> for a description of parameters.
The C<Proceed> parameter is ignored.

You cannot parse a file named C<"PICA::Parser"> by the way.

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
    } else { # called as a function
        $arg = ($self eq 'PICA::Parser') ? shift : $self;
        $parser = PICA::Parser->new( @_ );
    }

    croak("Missing argument to parsefile") unless defined $arg;
    $parser->parsefile( $arg );
}

=head2 parsedata ( $data [, %params ] )

Parses data from a string, array reference, or function. See
C<parsefile> and the C<parsedata> method of L<PICA::PlainParser>
and L<PICA::XMLParser> for a description of parameters.

By default L<PICA::PlainParser> is used unless there the
'Format' parameter set to 'xml':

  PICA::Parser->parsedata( $picastring, Field => \&field_handler );
  PICA::Parser->parsedata( \@picalines, Field => \&field_handler );

If data is a L<PICA::Record> object, it is directly passed to the 
record handler without re-parsing. See the constructor C<new> for 
a description of parameters. The C<Proceed> parameter is ignored.

=cut

sub parsedata {
    my $self = shift;
    my ( $data, $parser );

    if (ref($self) eq 'PICA::Parser') { # called as a method
        $data = shift;
        my %params = @_;
        $parser = $self->_getparser( %params );
    } else { # called as a function
        $data = ($self eq 'PICA::Parser') ? shift : $self;
        $parser = PICA::Parser->new( @_ );
    }

    $parser->parsedata( $data );
}

=head2 counter

Get the number of read records so far.

=cut

sub counter {
    my $self = shift;
    return undef if !ref $self;

    my $counter = 0;
    $counter += $self->{plainparser}->counter() if $self->{plainparser};
    $counter += $self->{xmlparser}->counter() if $self->{xmlparser};
    return $counter;
}

=head2 empty

Get the number of empty records that have been read so far.
Empty records are counted but not passed to the record handler 
unless you specify the C<EmptyRecords> parameter. The number
of non-empty records is the difference between C<counter> 
and C<empty>.

=cut

sub empty {
   my $self = shift; 
   return undef if !ref $self;

    my $empty = 0;
    $empty += $self->{plainparser}->empty() if $self->{plainparser};
    $empty += $self->{xmlparser}->empty() if $self->{xmlparser};
    return $empty;
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

Support multiple handlers per record?
Better logging needs to be added, for instance a status message every n records.
This may be implemented with multiple handlers per record (maybe piped). 
Handling of broken records should also be improved.

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007 by Verbundzentrale Goettingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

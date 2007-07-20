package PICA::Parser;

=head1 NAME

PICA::Parser - Parse PICA+ data

=head1 SYNOPSIS

  PICA::Parser->parsefile( $filename_or_handle ,
      Field => \&field_handler,
      Record => \&record_handler
  );

  PICA::Parser->parsedata( $string_or_function ,
      Field => \&field_handler,
      Record => \&record_handler
  );

=head1 DESCRIPTION

This module can be used to parse normalized PICA+ and PICA+ XML.
The conrete parsers are implemented in L<PICA::PlainParser> and 
L<PICA::XMLParser>.

=cut

use strict;
use warnings;

use Carp;

=head1 CONSTRUCTOR

=head2 new (params)

Creates a Parser to store common parameters (see below). These 
parameters will be used as default when calling C<parsefile> or
C<parsedata>. Note that you do not have to use the constructor to 
use C<PICA::Parser>. These two methods do the same:

  my $parser = PICA::Parser->new( %params );
  $parser->parsefile( $file );

  PICA::Parser->parsefile( $file, %params );

=cut

sub new {
    my ($class, %params) = @_;
    $class = ref $class || $class;

    my $self = bless {
        defaultparams => {},
        parser => undef
    }, $class;

    %{ $self->{defaultparams} } = %params if %params;

    return $self;
}

=head1 METHODS

=head2 parsefile (filename, params)

Parses pica data from a file, specified by a filename or filehandle.
The default parser is L<PICA::PlainParser>. If the filename extension 
is C<.xml> or C<.xml.gz> or the 'Format' parameter set to 'xml' then
L<PICA::XMLParser> is used instead. 

  PICA::Parser->parsefile( "data.picaplus", Field => \&field_handler );
  PICA::Parser->parsefile( \*STDIN, Field => \&field_handler, Format='XML' );

Common parameters that are passed to the specific parser are:

=over 4

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
by returning a modified record, but for performance reasons it 
is recommended to directly use the record instead of storing it.

=item Collection

Alias for C<EndCollection>. Ignored if C<EndCollection> is specified.

=item StartCollection

Reference to a handler function that is called before a 
collection of PICA+ record. Each file is treated as a 
collection so this is called before parsing a file.

=item EndCollection

Reference to a handler function for parsed PICA+ collections. 
An array of L<PICA::Record> objects is passed to the function.

=back

Additionally the following parameters are known to most parsers:

=over 4

=item Strict

Stop on errors (default is false)

=item EmptyRecords

Skip empty records so they will not be passed to the record handler
(default is false). Empty records easily occur for instance if your 
field handler does not return anything - this is useful for performance 
but you should not forget to set the EmptyRecords parameter. In every
case empty records are counted with a special counter that can be read 
with the C<empty_counter> method. The normal counter (method C<counter>) 
counts all records no matter if empty or not.

=back

=cut

sub parsefile {
    my ($self, $arg, %params) = @_;
    %params =  %{ $self->{defaultparams} } if ref $self and not %params;

    my $parser;

    if ( ($params{Format} and $params{Format} =~ /^xml$/i) or 
         (ref(\$arg) eq 'SCALAR' and ($arg =~ /.xml$/i or $arg =~ /.xml.gz$/i)) 
       ) {
        require PICA::XMLParser;
        $parser = PICA::XMLParser->new( %params );
    } else {
        require PICA::PlainParser;
        $parser = PICA::PlainParser->new( %params );
    }
    $self->{parser} = $parser if ref $self;

    $parser->parsefile( $arg );
}

=head2 parsedata (data, params)

Parses data from a string, array reference, or function. See
C<parsefile> and the C<parsedata> method of L<PICA::PlainParser>
and L<PICA::XMLParser> for a description of parameters.

By default L<PICA::PlainParser> is used unless there the
'Format' parameter set to 'xml':

  PICA::Parser->parsedata( $picastring, Field => \&field_handler );
  PICA::Parser->parsedata( \@picalines, Field => \&field_handler );

=cut

sub parsedata {
    my ($self, $data, %params) = @_;
    %params = %{ $self->{defaultparams} } if ref $self and not %params;

    my $parser;
    if ($params{Format} and $params{Format} =~ /^xml$/i) {
        require PICA::XMLParser;
        $parser = PICA::XMLParser->new( %params );
    } else {
        require PICA::PlainParser;
        $parser = PICA::PlainParser->new( %params );
    }
    $self->{parser} = $parser if ref $self;

    $parser->parsedata( $data );
}

=head2 counter

Get the number of read records so far.

=cut

sub counter {
   my $self = shift;
   return undef if !ref $self;

   my $parser = $self->{parser};
   return $parser->counter() if $parser;
}

=head2 empty_counter

Get the number of empty records that have been read so far.
Empty records are counted but not passed to the record handler 
unless you specify the C<EmptyRecords> parameter. The number
of non-empty records is the difference between C<counter> 
and C<empty_counter>.

=cut

sub empty_counter {
   my $self = shift; 
   return undef if !ref $self;

   my $parser = $self->{parser};
   return $parser->empty_counter() if $parser;
}

1;

__END__

=head1 TODO

Better logging needs to be added, for instance a status message every n records. This 
me be implemented with multiple handlers per record (maybe piped). Handling of broken 
records should also be improved.

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007 by Verbundzentrale Göttingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

Please note that these module s not product of or supported by the 
employers of the various contributors to the code nor by OCLC PICA.


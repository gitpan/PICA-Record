package PICA::Store;

use strict;
use utf8;

=head1 NAME

PICA::Store - CRUD interface to a PICA::Record storage

=head1 SYNOPSIS

 use PICA::Store;

 $server = PICA::Store->new( SOAP => $baseurl, $userkey, $password, $dbsid );
 %result = $server->get( $id );
 %result = $server->create( $record );
 %result = $server->update( $id, $record, $version );
 %result = $server->delete( $id );

=head1 DESCRIPTION

This class provided a simple retrieve-insert-update-delete - interface
to a record store. Currently there is only a CBS webcat SOAP-API but
you could also wrap for instance a Jangle interface with this class.

A formal description of the CBS webcat SOAP-API can be
found at http://cws.gbv.de/ws/webcatws.wsdl.

=cut


use PICA::Record;
use SOAP::Lite;
#use SOAP::Lite +trace => 'debug';
use Carp qw(croak);

our $VERSION = "0.4";

=head1 METHODS

=head2 new ( $type => $url, %params )

Create a new Server. You must specify at least a connection type and a base URL.
Other parameters are userkey, password, and database id. The optional language 
parameter (default: "en") for error messagescan be one of "de", "en", "fr" or "ne".

Currently only the connection type "SOAP" is supported with limited error handling.

=cut

sub new {
    my ($class, %params) = @_;

    croak "Missing SOAP base url" unless defined $params{SOAP};
    croak "Missing dbsid" unless defined $params{dbsid};
    croak "Missing userkey" unless defined $params{userkey};
    croak "Missing password" unless defined $params{password};

    $params{language} = "en" unless $params{language};

    my $soap = SOAP::Lite->on_fault(sub{})->proxy($params{SOAP}); # TODO: on_fault
    $soap->uri("http://www.gbv.de/schema/webcat-1.0")->encoding('utf8');

    bless {
        'soap' => $soap,
        'dbsid' => SOAP::Data->name( "dbsid" => $params{dbsid} )->type("string"),
        'userkey' => SOAP::Data->name( "userkey" => $params{userkey} )->type("string"),
        'password' => SOAP::Data->name( "password" => $params{password} )->type("string"),
        'language' => SOAP::Data->name( "language" => $params{language} )->type("string"),
        'format' => SOAP::Data->name( "format" => "pp" )->type("string"),
        'rectype_title' => SOAP::Data->name( "rectype" => "title" )->type("string"),
        'rectype_entry' => SOAP::Data->name( "rectype" => "entry" )->type("string")
    }, $class;
}

=head2 get ( $id )

Retrieve a record by ID.

Returns a hash with either 'errorcode' and 'errormessage'
or a hash with 'id', 'record', and 'version'. The 'record'
element contains a L<PICA::Record> object.

=cut

sub get {
    my ($self, $id) = @_;
    my %result = $self->_soap_query( "get", 
        SOAP::Data->name( "ppn" => $id )->type("string")
    );
    $result{record} = PICA::Record->new($result{record}) if $result{record};
    return %result;
}

=head2 create ( $record )

Insert a new record. The parameter must be a L<PICA::Record> object.

Returns a hash with either 'errorcode' and 'errormessage' or a hash
with 'id', 'record', and 'version'.

=cut

sub create {
    my ($self, $record) = @_;
    croak('create needs a PICA::Record object') unless ref($record) eq 'PICA::Record';
    my $rectype = $self->{"rectype_title"};

    my $sf = $record->subfield('002@$0');
    $rectype = $self->{"rectype_entry"} if ($sf && $sf =~ /^T/); # authority record

    # Don't ask me why SOAP::Lite breaks utf8
    my $recorddata = $record->to_string();
    utf8::decode($recorddata);

    return $self->_soap_query( "create",
        SOAP::Data->name( "record" )->type("string")->value( $recorddata ),
        $rectype
    );
}

=head2 update ( $id, $record, $version )

Update a record by ID, updated record (of type L<PICA::Record>),
and version (of a previous get, create, or update command).

Returns a hash with either 'errorcode' and 'errormessage'
or a hash with 'id', 'record', and 'version'.

=cut

sub update {
    my ($self, $id, $record, $version) = @_;
    croak('update needs a PICA::Record object') unless ref($record) eq 'PICA::Record';

    # Don't ask me why SOAP::Lite breaks utf8
    my $recorddata = $record->to_string();
    utf8::decode($recorddata);

    return $self->_soap_query( "update",
        SOAP::Data->name( "ppn" => $id )->type("string"),
        SOAP::Data->name( "record" )->type("string")->value( $recorddata ),
        SOAP::Data->name( "version" => $version )->type("string")
    );
}

=head2 delete ( $id )

Deletes a record by ID.

Returns a hash with either 'errorcode' and 'errormessage' or a hash with 'id'.

=cut

sub delete {
    my ($self, $id) = @_;
    return $self->_soap_query( "delete", 
        SOAP::Data->name( "ppn" => $id )->type("string")
    );
}

=head1 INTERNAL METHODS

=head2 _soap_query ( $operation, @params )

Internal method to prepare, perform and evaluate a SOAP request. Returns
a hash with 'errorcode' and 'errormessage' or a hash with 'dbsid', 'id',
'record', and 'version' depending on the type of query. Do not directly
call this method.

=cut

sub _soap_query {
    my ($self, $operation, @params) = @_;

    push @params, $self->{"format"} unless $operation eq "delete"; 
    push @params,
        $self->{dbsid},
        $self->{userkey},
        $self->{password},
        $self->{language};

    my $response = $self->{soap}->$operation( @params );

    my %result;
    if (!$response) { 
        $result{errorcode}    = "1";
        $result{errormessage} = "No response to SOAP operation '$operation'.";
    } elsif ($response->fault) {
        $result{errorcode}    = $response->faultcode;
        $result{errormessage} = $response->faultstring;
        chomp $result{errormessage};
    } else {
        my $rbody = $response->body->{response};
        if (defined $rbody) {
            $result{id} = $rbody->{ppn} if defined $rbody->{ppn};
            $result{record} = PICA::Record->new($rbody->{record}) if defined $rbody->{record};
            $result{version} = $rbody->{version} if defined $rbody->{version};
        }
    }

    return %result;
}

1;

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007-2009 by Verbundzentrale Goettingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

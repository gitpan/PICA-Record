package PICA::Store;

=head1 NAME

PICA::Store - CRUD interface to a PICA::Record storage

=head1 SYNOPSIS

 use PICA::Store;

 $server = PICA::Store->new( SOAP => $baseurl, $userkey, $password, $dbsid );
 %result = $server->retrieve( $id );
 %result = $server->insert( $record );
 %result = $server->update( $id, $record, $version );
 %result = $server->delete( $id );

=head1 DESCRIPTION

This class provided a simple retrieve-insert-update-delete - interface
to a record store. Currently there is only a CBS webcat SOAP-API but
you could also wrap for instance a Jangle interface with this class.

A formal description of the CBS webcat SOAP-API can be
found at http://cws.gbv.de/ws/webcatws.wsdl.

=cut

use strict;
use PICA::Record;
use SOAP::Lite;
#use SOAP::Lite +trace => 'debug';
use Carp qw(croak);

use utf8;

use vars qw($VERSION);
$VERSION = "0.39";

=head1 METHODS

=head2 new ( $type => $url, $userkey, $password, $dbsid [, $language ] )

Create a new Server. You must specify a connection type and base URL, 
userkey, password, and database id. The optional language (default: "en")
for error messagescan be one of "de", "en", "fr" or "ne".

Currently only the connection type "SOAP" is supported.

TODO: add SOAP error handling.

=cut

sub new {
    my ($class, $type, $baseurl, $userkey, $password, $dbsid, $language) = @_;

    croak unless $type eq 'SOAP'; # currently there is only SOAP
    croak "Missing SOAP base url" unless defined $baseurl;
    croak "Missing dbsid" unless defined $dbsid;
    croak "Missing userkey" unless defined $userkey;
    croak "Missing password" unless defined $password;

    $language = "en" unless $language;

    my $soap = SOAP::Lite->on_fault(sub{})->proxy($baseurl); # TODO: on_fault
    $soap->uri("http://www.gbv.de/schema/webcat-1.0")->encoding('utf8');

    bless {
        'soap' => $soap,
        'dbsid' => SOAP::Data->name( "dbsid" => $dbsid )->type("string"),
        'userkey' => SOAP::Data->name( "userkey" => $userkey )->type("string"), #->attr( { 'type' => 'xsd:string', } ),
        'password' => SOAP::Data->name( "password" => $password )->type("string"),
        'language' => SOAP::Data->name( "language" => $language )->type("string"),
        'format' => SOAP::Data->name( "format" => "PP" )->type("string"),
        'rectype_t' => SOAP::Data->name( "rectype" => "T" )->type("string"),
        'rectype_a' => SOAP::Data->name( "rectype" => "A" )->type("string") #->attr( { 'type' => 'xsd:string', } )
    }, $class;
}

=head2 retrieve ( $id )

Retrieve a record by ID.

Returns a hash with either 'errorcode' and 'errormessage'
or a hash with 'id', 'record', and 'version'. The 'record'
element contains a L<PICA::Record> object.

=cut

sub retrieve {
    my ($self, $id) = @_;
    my %result = $self->_soap_query( "retrieve", 
        SOAP::Data->name( "ppn" => $id )->type("string")
    );
    $result{record} = PICA::Record->new($result{record}) if $result{record};
    return %result;
}

=head2 insert ( $record )

Insert a new record. The parameter must be a L<PICA::Record> object.

Returns a hash with either 'errorcode' and 'errormessage' or a hash
with 'id', 'record', and 'version'.

=cut

sub insert {
    my ($self, $record, $rectype) = @_;
    croak('insert needs a PICA::Record object') unless ref($record) eq 'PICA::Record';
    if (!defined $rectype or ($rectype ne 'A' and $rectype ne 'T')) {
        my $sf = $record->subfield('002@$0');
        $rectype = 'A' if ($sf && $sf =~ /^T/); # authority record
    }
    $rectype = $self->{ $rectype eq 'A' ? "rectype_a" : "rectype_t" };

    # Don't ask me why SOAP::Lite breaks utf8
    my $recorddata = $record->to_string();
    utf8::decode($recorddata);

    return $self->_soap_query( "insert",
        SOAP::Data->name( "record" )->type("string")->value( $recorddata ),
        $rectype
    );
}

=head2 update ( $id, $record, $version )

Update a record by ID, updated record (of type L<PICA::Record>),
and version (of a previous retrieve, insert, or update command).

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
call this method!

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

__END__

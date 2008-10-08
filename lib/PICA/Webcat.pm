package PICA::Webcat;

=head1 NAME

PICA::Webcat - Access to the CBS webcat interface (experimental)

=head1 SYNOPSIS

use PICA::Webcat;

$server = PICA::Webcat->new( $baseurl, $userkey, $password, $dbsid );
%result = $server->retrieve( $ppn );
%result = $server->insert( $record );
%result = $server->update( $ppn, $record, $version );
%result = $server->delete( $ppn );

=cut

use strict;
use SOAP::Lite;
use Carp qw(croak);

use vars qw($VERSION);
$VERSION = "0.3";

=head1 METHODS

=head2 new ( $baseurl, $userkey, $password, $dbsid [, $language ] )

Create a new Server. You must specify a base URL, userkey, password,
and database id. The optional language (default: "en") can be one of
"de", "en", "fr" or "ne".

There is no error handling on failure yet!

=cut

sub new {
    my ($class, $baseurl, $userkey, $password, $dbsid, $language) = @_;

    $language = "en" unless $language;

    my $soap = SOAP::Lite->proxy($baseurl)->on_fault(sub{});
    $soap->uri("http://www.gbv.de/schema/webcat-1.0");

    bless {
        'soap' => $soap,
        'dbsid' => SOAP::Data->name( "dbsid" => $dbsid )->attr( { 'type' => 'xsd:string', } ),
        'userkey' => SOAP::Data->name( "userkey" => $userkey )->attr( { 'type' => 'xsd:string', } ),
        'password' => SOAP::Data->name( "password" => $password )->attr( { 'type' => 'xsd:string', } ),
        'language' => SOAP::Data->name( "language" => $language )->attr( { 'type' => 'xsd:string', } ),
        'format' => SOAP::Data->name( "format" => "PP" )->attr( { 'type' => 'xsd:string', } ),
        'rectype_t' => SOAP::Data->name( "rectype" => "T" )->attr( { 'type' => 'xsd:string', } ),
        'rectype_a' => SOAP::Data->name( "rectype" => "A" )->attr( { 'type' => 'xsd:string', } )
    }, $class;
}

=head2 retrieve ( $ppn )

Retrieve a record by PPN.

Returns a hash with either 'errorcode' and 'errormessage'
or a hash with 'ppn', 'record', and 'version'. The 'record'
element contains a L<PICA::Record> object.

=cut

sub retrieve {
    my ($self, $ppn) = @_;
    my %result = $self->_soap_query( "retrieve", 
        SOAP::Data->name( "ppn" => $ppn )->attr( { 'type' => 'xsd:string', } )
    );
    $result{record} = PICA::Record->new($result{record}) if $result{record};
    return %result;
}

=head2 insert ( $record )

Insert a new record. The parameter must be a L<PICA::Record> object.

Returns a hash with either 'errorcode' and 'errormessage' or a hash
with 'ppn', 'record', and 'version'.

=cut

sub insert {
    my ($self, $record, $rectype) = @_;
    if (!defined $rectype or ($rectype ne 'A' and $rectype ne 'T')) {
        my $sf = $record->subfield('002@$0');
        $rectype = 'A' if ($sf && $sf =~ /^T/); # authority record
    }
    $rectype = $self->{ $rectype eq 'A' ? "rectype_a" : "rectype_t" };
    croak('insert needs a PICA::Record object') unless ref($record) eq 'PICA::Record';
    return $self->_soap_query( "insert",
        SOAP::Data->name( "record" => $record->to_string() )->attr( { 'type' => 'xsd:string', } ),
        $rectype
    );
}

=head2 update ( $ppn, $record, $version )

Update a record by PPN, updated record (of type L<PICA::Record>),
and version (of a previous retrieve, insert, or update command).

Returns a hash with either 'errorcode' and 'errormessage'
or a hash with 'ppn', 'record', and 'version'.

=cut

sub update {
    my ($self, $ppn, $record, $version) = @_;
    croak('update needs a PICA::Record object') unless ref($record) eq 'PICA::Record';
    return $self->_soap_query( "update", 
        SOAP::Data->name( "ppn" => $ppn )->attr( { 'type' => 'xsd:string', } ),
        SOAP::Data->name( "record" => $record->to_string() )->attr( { 'type' => 'xsd:string', } ),
        SOAP::Data->name( "version" => $version )->attr( { 'type' => 'xsd:string', } )
    );
}

=head2 delete ( $ppn )

Deletes a record by PPN.

Returns a hash with either 'errorcode' and 'errormessage' or a hash with 'ppn'.

=cut

sub delete {
    my ($self, $ppn) = @_;
    return $self->_soap_query( "delete", 
        SOAP::Data->name( "ppn" => $ppn )->attr( { 'type' => 'xsd:string', } )
    );
}

=head2 _soap_query

Internal method to prepare, perform and evaluate a SOAP request. Returns
a hash with 'errorcode' and 'errormessage' or a hash with 'dbsid', 'ppn',
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

    if ($response->fault) {
        $result{errorcode}    = $response->faultcode;
        $result{errormessage} = $response->faultstring;
        chomp $result{errormessage};
    } else {
        my $rbody = $response->body->{response};
        if (defined $rbody) {
            $result{ppn} = $rbody->{ppn} if defined $rbody->{ppn};
            $result{record} = PICA::Record->new($rbody->{record}) if defined $rbody->{record};
            $result{version} = $rbody->{version} if defined $rbody->{version};
        }
    }

    return %result;
}

1;

__END__
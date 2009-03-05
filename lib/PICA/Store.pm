package PICA::Store;

=head1 NAME

PICA::Store - CRUD interface to a L<PICA::Record> storage

=cut

use strict;
use utf8;
our $VERSION = "0.45";

=head1 SYNOPSIS

  use PICA::Store;

  # connect to store
  $server = PICA::Store->new(
    SOAP => $baseurl, 
    userkey => $userkey, password => $password, dbsid => $dbsid 
  );

  # better get connection details from config file
  $server = PICA::Store->new( config => "myconf.conf" );
  $server = PICA::Store->new( config => undef ); # autodetect

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
use Config::Simple;
#use SOAP::Lite +trace => 'debug';
use Carp qw(croak);

=head1 METHODS

=head2 new ( %params )

Create a new Server. You must specify at least a connection type and a
base URL or the config file parameter to read this settings from a config
file. Defined parameters override settings in a config file.

Other parameters are userkey, password, and database id. The optional language 
parameter (default: "en") for error messagescan be one of "de", "en", "fr" or "ne".

Currently only the connection type "SOAP" is supported with limited error handling.

=cut

sub new {
    my ($class, %params) = @_;

    if (exists $params{config}) {
        my %config;
        my $cfile = $params{config};
        if (!(defined $cfile)) {
            if ($ENV{WEBCAT_CONF}) {
                $cfile = $ENV{WEBCAT_CONF};
            } elsif ( -f "./webcat.conf" ) {
                $cfile = "./webcat.conf";
            }
        }
        croak("config file (webcat.conf) not found") unless $cfile;
        Config::Simple->import_from( $cfile, \%config)
            or croak( "Failed to parse config file $cfile" );
        while (my ($key, $value) = each %config) {
            $key =~ s/default.//; # remove default namespace
            # TODO: add support of blocks/namespaces in config file
            $params{$key} = $value unless defined $params{$key};
        }
    }

    croak "Missing SOAP base url" unless defined $params{SOAP};
    croak "Missing dbsid" unless defined $params{dbsid};
    croak "Missing userkey" unless defined $params{userkey};

    $params{language} = "en" unless $params{language};

    my $soap = SOAP::Lite->on_fault(sub{})->proxy($params{SOAP}); # TODO: on_fault
    $soap->uri("http://www.gbv.de/schema/webcat-1.0")->encoding('utf8');

    my $password = $params{password};
    $password = "" unless defined $password;

    bless {
        'soap' => $soap,
        'dbsid' => SOAP::Data->name( "dbsid" )->type( string => $params{dbsid} ),
        'userkey' => SOAP::Data->name( "userkey" )->type( string => $params{userkey} ),
        'password' => SOAP::Data->name( "password" )->type( string => $password ),
        'language' => SOAP::Data->name( "language" )->type( string => $params{language} ),
        'format' => SOAP::Data->name( "format" )->type( string => "pp" ),
        'rectype_title' => SOAP::Data->name( "rectype" )->type( string => "title" ),
        'rectype_entry' => SOAP::Data->name( "rectype" )->type( string => "entry" )
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
        SOAP::Data->name( "ppn" )->type( string => $id )
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

    my $recorddata = $record->to_string();

    return $self->_soap_query( "create",
        SOAP::Data->name( "record" )->type( string => $recorddata ),
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

    my $recorddata = $record->to_string();

    return $self->_soap_query( "update",
        SOAP::Data->name("ppn")->type( string => $id ),
        SOAP::Data->name("record")->type( string => $recorddata ),
        SOAP::Data->name("version")->type( string => $version )
    );
}

=head2 delete ( $id )

Deletes a record by ID.

Returns a hash with either 'errorcode' and 'errormessage' or a hash with 'id'.

=cut

sub delete {
    my ($self, $id) = @_;
    return $self->_soap_query( "delete", 
        SOAP::Data->name( "ppn" )->type( string  => $id )
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
    push @params, ($self->{dbsid}, $self->{userkey}, $self->{language});
    push @params, $self->{password} if defined $self->{password};

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
            $result{record} = PICA::Record->new($rbody->{record}) 
		if defined $rbody->{record};
            $result{version} = $rbody->{version} if defined $rbody->{version};
        }
    }

    return %result;
}

1;

=head1 SEE ALSO

This distribution contains the command line client C<picawebcat> based on
PICA::Store.

=head1 AUTHOR

Jakob Voss <jakob.voss@gbv.de>

=head1 LICENSE

Copyright (C) 2007-2009 by Verbundzentrale Göttingen (VZG) and Jakob Voß

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

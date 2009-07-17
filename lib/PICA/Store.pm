package PICA::Store;

=head1 NAME

PICA::Store - CRUD interface to a L<PICA::Record> storage

=cut

use strict;
use Config::Simple;
use PICA::SOAPClient;
use PICA::SQLiteStore;
use Carp qw(croak);

our $VERSION = '0.48';

=head1 DESCRIPTION

This class is an abstract class to provide a simple CRUD
(create/insert, retrieve/get, update, delete) access to a 
record store of L<PICA::Record> objects. 

See L<PICA::SQLiteStore> and L<PICA::SOAPClient> for specific
implementations. Other implementations that may be implemented
later include WebDAV, and REST (for instance Jangle).

=head1 SYNOPSIS

  use PICA::Store;

  # connect to store via SOAP API (SOAPClient)
  $store = PICA::Store->new( SOAP => $baseurl, %params );

  # connect to SQLiteStore
  $store = PICA::Store->new( SQLite => $dbfile, %params );

  # Get connection details from a config file
  $store = PICA::Store->new( config => "myconf.conf" );

  # CRUD operations
  %result = $store->get( $id );
  %result = $store->create( $record );
  %result = $store->update( $id, $record, $version );
  %result = $store->delete( $id );

  # set additional access parameters
  $store->access( userkey => $userkey, password => $passwd );

=cut

our $readconfigfile = sub {
    my $params = shift; # hash reference
    return unless defined $params->{config} or defined $params->{conf};

    my $cfile = $params->{config} || $params->{conf};    
    my %config;

    croak("config file not found: $cfile") unless -e $cfile;
    Config::Simple->import_from( $cfile, \%config)
        or croak( "Failed to parse config file $cfile" );

    while (my ($key, $value) = each %config) {
        $key =~ s/default.//; # remove default namespace
        # TODO: add support of blocks/namespaces in config file
        $params->{$key} = $value unless exists $params->{$key};
    }
};

=head1 METHODS

=head2 new ( %parameters )

Return a new PICA::Store. You must either specify a parameter named
'SOAP' to get a L<PICA::SOAPClient> or a parameter named 'SQLite' 
to get a L<PICA::SQLiteStore>. Alternatively you can specify a
parameter named 'config' that points to a configuration file.

=cut

sub new {
    my ($class, %params) = (@_);

    $readconfigfile->( \%params ) if defined $params{config};

    return PICA::SOAPClient->new( %params ) if defined $params{SOAP};
    return PICA::SQLiteStore->new( %params ) if defined $params{SQLite};

    undef;
}

# TODO: load from config file

=head2 get

Retrieve a record.

=cut

sub get {
    croak('abstract method "get" is not implemented');  
}

=head2 create

Insert a new record.

=cut

sub create {
    croak('abstract method "create" is not implemented');  
}

=head2 update

Update an existing record.

=cut

sub update {
    croak('abstract method "update" is not implemented');  
}

=head2 delete

Delete a record.

=cut

sub delete {
    croak('abstract method "delete" is not implemented');  
}

=head2 access ( key => value ... )

Set general access parameters (userkey, password, dbsid and/or language).
Returns the store itself so you can chain anothe method call. By default
the parameters are just ignored so any subclass should override this 
method to make sense of it.

=cut

sub access {
    my ($self, %params) = @_;

    for my $key (qw(userkey password dbsid language)) {
        # do nothing
    }

    return $self;
}

1;

=head1 SEE ALSO

This distribution contains the command line client C<picawebcat> 
based on PICA::Store. See also L<PICA::SQLiteStore>, L<PICA::SOAPClient>,
and L<PICA::SOAPServer>.

=head1 AUTHOR

Jakob Voss <jakob.voss@gbv.de>

=head1 LICENSE

Copyright (C) 2007-2009 by Verbundzentrale Goettingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

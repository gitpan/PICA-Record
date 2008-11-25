#!/usr/bin/perl

=head1 NAME

webcat - command line interface to webcat

=cut

use strict;

use PICA::Store;
use Getopt::Long 2.33;
use Pod::Usage;
use PICA::Parser;
use Data::Dumper;
use utf8;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

our $VERSION = "0.2";

my ($soapbase, $dbsid, $user, $password, $language);
my ($simulate, $command, $quiet);

GetOptions(
    'soap=s' => \$soapbase,
    'dbsid=s' => \$dbsid,
    'user=s' => \$user,
    'password=s' => \$password,
    'language=s' => \$language,
    'simulate' => \$simulate,
    'quiet' => \$quiet,
) or pod2usage(2);

my $webcat = eval { 
    PICA::Store->new( SOAP => $soapbase, $user, $password, $dbsid );
};
error( "Failed to connect!") unless $webcat;

$command = shift @ARGV;
if ($command =~  /^r.*/) { # retrieve
    error ("please provide ID(s) to retrieve") unless @ARGV;
    foreach my $id (@ARGV) {
        action("retrieve", $id);
    }
} elsif ($command =~  /^d.*/) { # delete
    error ("please provide ID to retrieve") unless @ARGV;
    my $id = shift @ARGV;
    error ("You can only delete one record with one call") if @ARGV;
    action("delete", $id);
} elsif ($command =~ /^i.*/) { # insert
    error ("please provide input file(s) to insert") unless @ARGV;
    foreach my $filename (@ARGV) {
        my @records = PICA::Parser->parsefile( $filename )->records();
        print "read " . (scalar @records) . " records from $filename\n" unless $quiet;
        foreach my $r (@records) {
            action("insert", $r);
        }
    }
} elsif ($command =~ /^u.*/) { # update
    error ("please provide ID to update") unless @ARGV;
    my $id = shift @ARGV;
    error ("please provide an input file to update") unless @ARGV;
    my $filename = shift @ARGV;
    my @records = PICA::Parser->parsefile( $filename )->records();
    error ("input file must contain exactely one record") unless @records == 1;

    my $version = shift @ARGV;
    if (!defined $version && !$simulate) {
        my %result = $webcat->retrieve( $id );
        error( $result{errorcode}, $result{errormessage} ) if ( defined $result{errorcode} );
        $version = $result{version};
    }
    action("update", $id, shift @records, $version );

} else {
    error("please provide a retrieve, insert, update, or delete command");
}


sub action {
    my ($command, @params) = @_;

    print "$command: " . join(' ', @params ) . "\n" unless $quiet;
    return if $simulate;

    my %result = $webcat->$command( @params);
    error( $result{errorcode}, $result{errormessage} ) if ( defined $result{errorcode} );

    return if $quiet;
    print "id: " . $result{id} . "\n" if defined $result{id};
    print "version: " . $result{version} . "\n" if defined $result{version};
    print "record:\n" . $result{record}->to_string() . "\n" if defined $result{record};
}


# print error message/code and exit
sub error {
    my ($errorcode, $errormessage) = @_;
    if (defined $errormessage) {
        print STDERR "ERROR $errorcode: $errormessage\n";
        exit $errorcode;
    } else {
        print STDERR "ERROR: $errorcode\n";
        exit 1;
    }

}

__END__

=head1 SYNOPSIS

webcat [options] insert <file(s)> | update <id> <file> | delete <id> | retrieve <id(s)>

   Options:
     -help            brief help message
     -man             full documentation
     -version         print version of this script
     -soap     URL    set SOAP interface base URL
     -user     USER   set user
     -password PWD    set password
     -language LNG    set language
     -quiet           do not print messages and results
     -simulate        simluate only (list records that would be loaded, TODO)

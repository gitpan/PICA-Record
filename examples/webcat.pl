#!/usr/bin/perl

use strict;
use utf8;

=head1 NAME

webcat.pl - Command line interface to L<PICA::Store>

=cut

use PICA::Store 0.4;
use Getopt::Long 2.33;
use Pod::Usage;
use PICA::Parser;
use Data::Dumper;

binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

our $VERSION = "0.4";

my ($soap, $dbsid, $userkey, $password, $language);
my ($help, $man, $version,$command);
my $config = $ENV{WEBCAT_CONFIG};

GetOptions(
    'config=s' => \$config,
    'soap=s' => \$soap,
    'dbsid=s' => \$dbsid,
    'userkey=s' => \$userkey,
    'password=s' => \$password,
    'language=s' => \$language,
    'version' => \$version,
    'help|?' => \$help,
    'man' => \$man
) or pod2usage(2);

pod2usage(0) if $help;
pod2usage(-verbose => 2) if $man;
if ($version) {
    pod2usage(-msg => "This is webcat version $VERSION\n", -exitval => 0);
}

$command = shift @ARGV
    || error("please provide a command (use option -? or -m for help)");

my %commands = map { substr($_, 0, length($command)) => $_ }
    ("get","create","update","delete");

$command = $commands{$command}
    || error("please provide a valid command");

$config = "webcat.conf" unless $config || ! -r "webcat.conf";
if ($config) {
    open(CONF, "<$config") || error("Failed to open $config");
    while(<CONF>) {
        chomp;
        s/^\s+|#.*$|\s+$//g;
        if ( /^soap\s*=\s*([^ ]+)/ ) {
            $soap = $1 unless defined $soap;
        } elsif ( /^userkey\s*=\s*([^ ]+)/ ) {
            $userkey = $1 unless defined $userkey;
        } elsif ( /^password\s*=\s*([^ ]+)/ ) {
            $password = $1 unless defined $password;
        } elsif ( /^dbsid\s*=\s*([^ ]+)/ ) {
            $dbsid = $1 unless defined $dbsid;
        } elsif ( /^language\s*=\s*([^ ]+)/ ) {
            $language = $1 unless defined $language;
        }
    }
    close CONF;
}

pod2usage("please provide soap, userkey, password, dbsid")
    unless $soap && $userkey && $password && $dbsid;

my $webcat = PICA::Store->new(
        SOAP => $soap,
        userkey => $userkey, 
        password => $password,
        dbsid => $dbsid 
);

error( "Failed to connect!") unless $webcat;

if ($command eq "get") {
    error ("please provide ID(s) to get") unless @ARGV;
    foreach my $id (@ARGV) {
        action("get", $id);
    }
} elsif ($command eq "delete") {
    my $id = shift @ARGV || error ("please provide an ID");
    error ("You can only delete one record with one call") if @ARGV;
    action("delete", $id);
} elsif ($command eq "create") {
    error ("please provide input file(s) to create") unless @ARGV;
    foreach my $filename (@ARGV) {
        my @records = PICA::Parser->parsefile( $filename )->records();
        foreach my $r (@records) {
            action("create", $r);
        }
    }
} elsif ($command eq "update") {
    my $id = shift @ARGV || error ("please provide an ID");
    my $filename = shift @ARGV || error ("please provide an input file");

    my @records = PICA::Parser->parsefile( $filename )->records();
    error ("input file must contain exactely one record") unless @records == 1;

    my $version = shift @ARGV;
    if (!defined $version) {
        my %result = $webcat->get( $id );
        error( $result{errorcode}, $result{errormessage} ) if ( defined $result{errorcode} );
        $version = $result{version};
    }
    action("update", $id, shift @records, $version );

}

# perform action and print return value
sub action {
    my ($command, @params) = @_;

    my %result = $webcat->$command( @params);
    error( $result{errorcode}, $result{errormessage} ) if defined $result{errorcode};

    if ($command eq "get") {
        print $result{record}->to_string();
    } elsif ($command eq "update") {
        print $result{version} . "\n";
    } else {
        print $result{id} . "\n";
    }
}


# print error message/code and exit
sub error {
    my ($errorcode, $errormessage) = @_;
    if (defined $errormessage) {
        print STDERR "ERROR $errorcode: $errormessage\n";
        exit $errorcode;
    } else {
        print STDERR "$errorcode\n";
        exit 1;
    }

}

__END__

=head1 SYNOPSIS

webcat [options] <command>

   Commands:
     get    <id(s)>
     create <file(s)>
     update <id> <file> [<version>]
     delete <id>

   Options:
     -config    <file>   set config file (see description with -m)
     -dbsid     <dbsdi>  set database id
     -help               brief help message
     -language  <lang>   set language code
     -man                full documentation
     -password  <pwd>    set password
     -soap      <url>    set SOAP interface base URL
     -userkey   <user>   set user
     -version            print version of this script

=head1 DESCRIPTION

By default the script first looks whether the environment variable 
WEBCAT_CONFIG points to a config file, otherwise whether a file named 
"webcat.conf" located in the current directory exists. You can override
the file with the config parameter. The config file can contain 
key=value pairs of dbsid, soap, userkey, password, language.

If an error occurred, the error message is send to STDOUT and the script
ends with error code. On success the following information is print:

  on get: the record(s) data
  on update: the new version
  on create and delete: the id(s)

Examples:

  webcat.pl get 000000477
  webcat.pl delete 000000477
  webcat.pl create myrecord.pica
  webcat.pl update 000000477 myrecord.pica

=cut

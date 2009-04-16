#!perl -Tw

use strict;

use Test::More qw(no_plan);
use URI::Escape qw(uri_escape uri_escape_utf8 uri_unescape);
use Encode;

use_ok("PICA::Filemap");

my $m = new PICA::Filemap("foo");
my $u = [undef,undef,undef];
my $t = "2008-12-31T10:42:23";
my $unicode = chr(0x263a).chr(228).chr(246).chr(252); 
my $uniesc = "%E2%98%BA%C3%A4%C3%B6%C3%BC";
my $inpath1 = decode_utf8("path/").$unicode;
my $inpath2 = "path/$uniesc";

is( undef, $m->parseline("# comment") );
is( undef, $m->parseline(" # comment") );
is( undef, $m->parseline(" ") );
is( undef, $m->parseline("") );
is( undef, $m->parseline("$t") );

is_deeply( [undef,"file",undef], [ $m->parseline("file") ] );
is_deeply( [undef,"file","id"], [ $m->parseline("file  id") ] );
is_deeply( [$t,"file","id"], [ $m->parseline("$t  file id") ] );
is_deeply( [$t,"file",undef], [ $m->parseline("$t file #id") ] );
is_deeply( [undef,"file name",undef], [ $m->parseline("file%20name") ] );

my $r = [ $m->parseline($uniesc) ];
is( decode_utf8($r->[1]), $unicode );

my %lines = (
    " filename" => "filename",
    " filename 123" => "filename 123",
    "filename 123 foo" => "filename 123",
    " $t filename" => "$t filename",
    "$t filename 42" => "$t filename 42",
    "file%20name" => "file%20name",
    $unicode => $uniesc,
    $uniesc => $uniesc,
    $inpath1 => $inpath2,
    $inpath2 => $inpath2,
);

while (my ($from, $to) = each(%lines)) {
    is( $m->createline( $m->parseline( $from ) ), $to );
}

$m = PICA::Filemap->new(\*DATA);
is( $m->read(), 5 );
is( $m->size(), 5 );

# test method 'id2file'
is( $m->id2file("id3"), "file3" );
is( $m->id2file("idX"), undef );
is( $m->id2file("id5"), "file5" );

# test method 'file2id'
is( $m->file2id("file1"), undef );
is( $m->file2id("file5"), "id5" );
is( $m->file2id("fileX"), undef );

# test method 'delete'
$m->delete('id3');
is( $m->size(), 4 );

ok( $m->files(), "files" );
ok( $m->ids(), "ids" );

# TODO: more tests (create, update, delete, add ...)

#$m->remove
#use Data::Dumper;
#print Dumper($m);

__DATA__
file1
file2
file3 id3
2009-01-20T10:52:17 file4
2009-01-20T10:52:18 file5 id5
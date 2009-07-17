#!/usr/bin/perl

=head1 NAME 

PICA+Wiki - Wiki interface to a L<PICA::Store> of PICA+ records

=head1 DESCRIPTION

This is just a proof of concept and needs a major rewrite. To try
out, create a file picawiki.conf point with SQLite=sqlitefile.db 
to a file that is writeable to your webserver.

=cut


#use lib "../lib";

use CGI qw/:standard :form/;
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use URI::Escape;
use PICA::Record;
use PICA::SQLiteStore;
use Data::Dumper;
use File::Basename;
use Cwd qw(abs_path);

# TODO: error handling if this fails (installation)
# TODO: add wsdl and soap files

my $store = eval { PICA::SQLiteStore->new( config => "picawiki.conf" ); };
my $error = $@;

my $PICAWIKI_VERSION = "0.1.0";

my $baseurl = url(-full => 0);
my $title = "PICA+Wiki";
my $css = <<CSS;
body { font-size:small; font-family:sans-serif; margin:0; padding:0; height:100%; }
#page-base { height:5em; }
#head-pase { height:5em; margin-left:12em; margin-top:-5em; }
#content { margin-left:12em; padding:1em; line-height:1.5em; border: 1px solid #0AD; }
#head { position:absolute; right:0; top:0; width:100%; }
#bodyContent { }
#panel { left:0; position:absolute; top:4em; width:12em; }
div.portal { padding: 0; }
div.portal h5 { color:#666666; font-size:118%; font-weight:normal; margin:0; padding:2em 0 0 1.25em; }
div.portal div { margin:0 0 0 1.25em; padding-top:0.5em; }
div.portal div ul { list-style: none; margin:0; padding:0; }
div.portal div ul li { margin:0; overflow:hidden; padding:0; 0 0.5em; }
#personal { position:absolute; right:0.75em; top:0; }
#left-navigation { left:12em; position:absolute; top:3em; }
#left-navigation ul { list-style: none; height:100%; padding:0; margin:0; }
#left-navigation ul li {
float: left;
  margin: 0.2em 0em;
  padding: 0em 1em 0em 1em;
 display:block; 
}
#title { padding: 0.5em; display:block; height:3em; width:12em; }
#title h1 { font-size: 188%; font-weight: bold; }
div.error { border: 1px solid #a00; padding: 0.5em; color: #a00; background: #fcc; margin-bottom: 1em;}
h2 { padding-bottom: 0.25em; margin: 0; border-bottom: 1px solid #0AD; }
pre { background: #eee; font-size: 150%; padding: 0.5em; border: 1px dotted #aaa; } 
CSS
 
my $ppn = param('ppn');
my $cmd = param('cmd');
my $record = param('record');
my $version = param('version');
my $submit = param('submit');
my $cancel = param('cancel');

my $user = $ENV{REMOTE_ADDR} or "0";
$store->access( userkey => $user ) if defined $user;

my $c_user = param('user');
$cmd = 'contributions' if defined $c_user and not $cmd;

$cmd = '' if ($error);

print header({type => 'text/html', charset => 'utf-8'});
print start_html(
    -encoding => 'utf-8',
    -style=>{-code=>$css},
    title=>$title,
);

#print pre( { class => 'debug' }, "hallo" );
#print $baseurl;

print "<div id='page-base' class='noprint'></div>\n";
print "<div id='head-base' class='noprint'></div>\n";
print "<div id='content'>\n";
print "<a id='top' name='top'></a>\n";
print "<div id='bodyContent'>\n";

# cancel action
if ($cancel) {
    if ($cmd eq 'editrecord') {
        $cmd = 'viewrecord'; $version = 0;
    }
    # TODO: redirect to get HTTP GET (?)
}
$cmd = 'viewrecord' if ( ($ppn or $version) and not $cmd);
$cmd = '' if $cmd eq 'viewrecord' and not ($ppn or $version); 

if ($cmd eq 'editrecord' && $submit) {
    # TODO: nicht wenn version fehlt
    $record =~ s/\t/ /g;
    $record =~ s/ +/ /g;
    my $pprecord = eval { PICA::Record->new( $record ); };
    $pprecord = 0 if $pprecord && $pprecord->is_empty;
    if ($pprecord) {
        my %result = ();
        if ($ppn) {
            %result = $store->update( $ppn, $pprecord, $version );
        } else {
#print "CREATE: " . $pprecord->to_string();
            %result = $store->create( $pprecord );
        }
        if (%result) {
            if ($result{id}) {
                $ppn = $result{id};
                $cmd = 'viewrecord';
            } else {
                $error = "ERROR: " . $result{errormessage};
            }
            $version = $result{version};
        } else {
            $error = "Fehler beim Speichern des Datensatz";
        }
    } else {
        $error = $@ ? $@ : "Der Datensatz ist kein PICA+";
    }
}

if ($cmd eq 'newrecord') {
    $record = "";
    $version = "";
    $cmd = "editrecord";
} 

#if ($version && !$cmd) {
#    $cmd = 'viewrecord';
#}

if ($cmd eq 'viewrecord') {
    my %recorddata;
    if ($version) {
        %recorddata = $store->get( $ppn, $version );
    } elsif ($ppn) {
        %recorddata = $store->get( $ppn );
    }
    if ($recorddata{id}) {
        $ppn = $recorddata{id};
        $record = $recorddata{record}->to_string;
        $version = $recorddata{version};
        $timestamp = $recorddata{timestamp};
        $latest = $recorddata{latest};
    } else {
        $error = "Failed to get record $ppn version $version";
        $cmd = "";
    }
}

print div({class=>'error'},$error) if $error;

if ($cmd eq 'editrecord') {
    my %rec;
    if ($ppn and not $version) {
        my %rec = $store->get( $ppn ); # TODO: vorher machen, und wenn nicht vorhanden: fehler
        $record = $rec{record}->to_string;
        $version = $rec{version};
    }
    print h2( $ppn ? "Datensatz $ppn bearbeiten" : "Datensatz anlegen" );
    print "Version $version" if $version;
    print start_form( { action=>$baseurl, method=>'post' } );
    print input( {type=>'hidden', name=>'cmd', value=>'editrecord'} );
    print input( {type=>'hidden', name=>'ppn', value=>$ppn} );
    print input( {type=>'hidden', name=>'version', value=>$version} );
    print textarea( { name=>'record', style=>'width:100%', rows=>25, cols=>80, value=>$record } );
    print br,
        input( { type=>'submit', name=>'submit', value=>($ppn?'Speichern':'Anlegen') } ),
        input( { type=>'submit', name=>'cancel', value=>'Abbrechen' } );
    print end_form;

} elsif($cmd eq 'viewrecord') {
    print h2("Datensatz $ppn");
    if ($version) {
        my $prevnext = $store->prevnext($ppn, $version, 1);
        my @pn = sort keys %$prevnext;
        my $n = shift @pn;
        if ($n && $n < $version) {
            print a({href=>"$baseurl?version=".$n}, " \x{2190} " );
            $n = shift @pn;
        }
        print "Version id $version ";
        print " ($timestamp)" if $timestamp;
        if ($n && $n > $version) {
            print a({href=>"$baseurl?version=".$n}, " \x{2192} ");
        }
        # TODO: add user
        if ($latest && $version < $latest) {
            print " Von diesem Datensatz existiert eine " 
                  . a({href=>"$baseurl?ppn=$ppn"}, "aktuelle Version") . "!";
        }
    }

    print pre($record);
    print div(a({href=>"$baseurl?cmd=editrecord&ppn=$ppn"}, "Bearbeiten"));
    #print div(a({href=>"$baseurl?cmd=deleterecord&ppn=$ppn"}, "Löschen"));

} elsif ($cmd eq 'history' and $ppn) {
    print h2("Versionen von Datensatz $ppn");
    $history = $store->history($ppn);
    print "<ul>";
    foreach my $item (@$history) {
        print "<li>";
        print a( { href=>"$baseurl?version=" . $item->{version} }, $item->{timestamp} );
        print " <b>neu</b>" if ($item->{is_new}); # should only be one of this two
        print " <b>gelöscht</b>" if ($item->{deleted});
        print " von " . a({ href=>"$baseurl?user=".$item->{user} }, $item->{user});
        print "</li>";
    }
    print "</ul>";
    # print Dumper($history);
} elsif ($cmd eq 'contributions') {
    print h2("Bearbeitungen von $c_user");
    $revisions = $store->contributions($c_user);
    print div("Es liegen keine Bearbeitungen dieses Accounts vor.") unless @$revisions;
    print "<ul>";
    foreach my $item (@$revisions) {
        print "<li>";
        print a( { href=>"$baseurl?version=" . $item->{version} }, $item->{timestamp} );
        print " ";
        print a( { href=>"$baseurl?ppn=" . $item->{ppn} }, "Datensatz " . $item->{ppn} );
        print " <b>neu</b>" if ($item->{is_new});
        print " <b>gelöscht</b>" if ($item->{deleted});
        print "</li>";
    }
    print "</ul>";    
} elsif ($cmd eq 'recentchanges') {
    print h2("Letzte Änderungen");
    $rc = $store->recentchanges();
    if (!@$rc) {
        print div("Es liegen keine Änderungen vor.");
    }
    print "<ul>"; # TODO: Gelöschte Datensätze markieren!
    foreach my $item (@$rc) {
        print "<li>";
        print a( { href=>"$baseurl?version=" . $item->{version} }, $item->{timestamp} );
        print " ";
        print a( { href=>"$baseurl?ppn=" . $item->{ppn} }, "Datensatz " . $item->{ppn} );
        print " <b>neu</b>" if ($item->{is_new});
        print " <b>gelöscht</b>" if ($item->{deleted});
        print " von " . a({ href=>"$baseurl?user=".$item->{user} }, $item->{user});
        print "</li>";
    }
    print "</ul>";
    # print Dumper($rc);    
} elsif ($cmd eq 'stats') {
    print h2("Statistik");
    my %stats = getStats();
    print '<div>';
    print '<dl>';
    print map { dt($_) . dd($stats{$_}); } (keys %stats);
    print '</dl>';
    print '</div>';
} elsif ($cmd eq 'deleted') {
    print h2("Gelöschte Datensätze");
    my $del = $store->deleted();
    if (@$del) {
        print "<ul>";
        foreach my $item (@$del) {
            print "<li>";
            print a( { href=>"$baseurl?version=" . $item->{version} }, $item->{timestamp} );
            print " ";
            print a( { href=>"$baseurl?ppn=" . $item->{ppn} }, "Datensatz " . $item->{ppn} );
            print " <b>gelöscht</b> von " . a({ href=>"$baseurl?user=".$item->{user} }, $item->{user});
            print "</li>";
        }
        print "</ul>";
    } else {
        print "Es liegen keine gelöschten Datensätze vor.";
    }
} else { # startseite
    print h2("$title");
    print "<div>";
    print "Herzlich Willkommen zur ersten Demo des PICAWiki. Hier können Datensätze im ";
    print a({href=>"http://www.gbv.de/wikis/cls/PicaPlus"},"PICA+ Format") . " angelegt und bearbeitet werden.";
    print "</div>";
    #if (!$store) {
    #print div("Bitte lesen Sie sich die Installationsanweisung durch!");
    #}
}

print "</div>";
print "</div><!-- content -->\n";
print "<div id='head' class='noprint'>\n";

print div({id=>'title'}, h1($title) ) . "\n";
print div({id=>'personal'}, span($user));

print "<div id='left-navigation'>";
if ($ppn) {
    print "<ul>";
    print "<li><a href='$baseurl?ppn=$ppn'><span>Datensatz</span></a></li>";
    print "<li><a href='$baseurl?cmd=history&ppn=$ppn'><span>Versionen</span></a></li>";
    print "</ul>";
}
print "</div>\n";
print "</div> <!-- head -->";
print "<div id='panel' class='noprint'>\n";

my @panel = (
  'Navigation', [
      $baseurl, 'Startseite',
      "$baseurl?cmd=recentchanges", 'Letzte Änderungen',
     # "$baseurl?cmd=listrecords", 'Alle Datensätze'
  ],
  'Werkzeuge', [
      "$baseurl?cmd=newrecord", 'Neuer Datensatz',
      "$baseurl?cmd=stats", 'Statistik',
      "$baseurl?cmd=deleted", 'Löschlog'
  ]
);
for(my $i=0; $i<@panel; $i+=2) {
    my @list = @{$panel[$i+1]};
    print '<div class="portal">' . h5($panel[$i]) . '<div><ul>';
    for(my $j=0; $j<@list; $j+=2) {
        print li(a({href=>$list[$j]},$list[$j+1]));
    }
    print '</ul></div></div>';
}
print "</div> <!-- panel -->\n";

print "<div class='break'/>\n";
print "<div id='foot'><!-- footer --></div>\n";
print end_html;


sub getStats {
    my %stat;

    #my @s = stat($dbfile);
    #$stat{dbfilename} = $dbfile;
    #$stat{dbfilesize} = $s[7];
    #$stat{dbfilemtime} = $s[9];
    #$stat{wikiversion} = $PICAWIKI_VERSION;

    return %stat;    
}

=head1 SEEALSO

HTML and CSS design is adopted from the MediaWiki Vector theme.

=cut

__END__

TODO: 
- allow to query raw PICA via same URL-parameters as PSI and via unAPI
- add SOAP server to emulate CBS Webcat


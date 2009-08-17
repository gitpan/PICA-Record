use 5.005;
use strict;
use ExtUtils::MakeMaker;

&WriteMakefile(
    NAME            => 'PICA::Record',
    DISTNAME        => 'PICA-Record',
    VERSION_FROM    => 'lib/PICA/Record.pm',
    ABSTRACT_FROM   => 'lib/PICA/Record.pm',
    PMLIBDIRS       => [ qw( lib/ ) ],
    AUTHOR          => 'Jakob Voss <jakob.voss@gbv.de>',
    PREREQ_PM       => {
        'LWP::Simple' => '1.0',
        'URI::Escape' => '1.35',
        'SOAP::Lite' => '0.71',
        'Scalar::Util' => '1.14',
        'Config::Simple' => '4.58',
        'PerlIO' => '1.0',
        'IO::File' => '1.11',
        'IO::Scalar' => '1.126',
        'Encode' => '2.33',
        'XML::Parser' => '2.32',
        'XML::Writer' => '0.605',
        'DBI' => '1.0',
        'DBD::SQLite' => '1.23',
        'Unicode::Normalize' => '0.23',
    },
    EXE_FILES       => [ 
        'script/parsepica', 
        'script/picaimport',
	'script/winibw2pica',
    ],
    dist            => {
        COMPRESS => 'gzip -9f',
        SUFFIX => 'gz',
    },
    depend          => {
        Makefile => '$(VERSION_FROM)'
    },
    clean           => { FILES => 'PICA-Record-*' },
);

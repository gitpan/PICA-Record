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
        'XML::Parser' => '2.32',
        'LWP::UserAgent' => '2.0',
        'URI::Escape' => '1.35',
        'SOAP::Lite' => '0.71',
        'Scalar::Util' => '1.18',
        'Config::Simple' => '4.58',
        'IO::File' => '1.11',
        'Encode' => '2.33',
        'XML::Writer' => '0.605'
    },
    EXE_FILES       => [ 'script/parsepica', 'script/picawebcat' ],
    dist            => {
        COMPRESS => 'gzip -9f',
        SUFFIX => 'gz',
    },
    depend          => {
        Makefile => '$(VERSION_FROM)'
    },
    clean           => { FILES => 'PICA-Record-*' },
);

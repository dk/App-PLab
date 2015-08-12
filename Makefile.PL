use strict;
use warnings;
use ExtUtils::MakeMaker;
my @programs_to_install = qw(ManCen MorphometryI PrLenS PrAverB select_button_glyph);

WriteMakefile(
    NAME	 => 'App::PLab::ImageApp',
    VERSION_FROM => 'lib/App/PLab/ImageApp.pm', # finds $VERSION
    EXE_FILES    => [ map {("bin/$_")} @programs_to_install ],
    PL_FILES     => { map {("bin/$_.PL" => "bin/$_")} @programs_to_install },
    dist         => {COMPRESS => 'gzip -9f',
		      SUFFIX   => '.gz',
		      DIST_DEFAULT => 'all tardist',
		     },
    DISTNAME => 'App::PLab',
    ABSTRACT => 'Internal PLab image processing tools',
    AUTHOR   => 'Dmitry Karasik <dk@plab.ku.dk>, Anton Berezin <tobez@plab.ku.dk>, Vadim Belman <voland@plab.ku.dk>',
);



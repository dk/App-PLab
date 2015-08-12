use strict;
use warnings;
use ExtUtils::MakeMaker;
my @programs_to_install = qw(ManCen MorphometryI PrLenS PrAverB select_button_glyph);

WriteMakefile(
    NAME	 => 'App::PLab',
    VERSION_FROM => 'lib/App/PLab/ImageApp.pm',
    EXE_FILES    => [ map {("bin/$_")} @programs_to_install ],
    PREREQ_PM    => {
    	Prima         => 0,
	IPA           => 0,
	'XML::Parser' => 0,
    },
    ABSTRACT     => 'Internal PLab image processing tools',
    AUTHOR       => 'Dmitry Karasik <dk@plab.ku.dk>, Anton Berezin <tobez@plab.ku.dk>, Vadim Belman <voland@plab.ku.dk>',
);



use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my @programs_to_install = qw(ManCen MorphometryI PrLenS PrAverB);

WriteMakefile(
    'NAME'	=> 'PLab::Prima::ImageApp',
    'VERSION_FROM' => 'lib/PLab/Prima/ImageApp.pm', # finds $VERSION
    'EXE_FILES'    => [ map {("bin/$_.PL")} @programs_to_install ],
    'dist'         => {COMPRESS => 'gzip -9f',
		      SUFFIX   => '.gz',
		      DIST_DEFAULT => 'all tardist',
		     },

    'DISTNAME'     => 'PLab-Prima-IPA-tools',
    ($] >= 5.005 ?
        (
            ABSTRACT => 'Internal PLab image processing tools',
            AUTHOR   => 'Dmitry Karasik <dk@plab.ku.dk>, Anton Berezin <tobez@plab.ku.dk>, Vadim Belman <voland@plab.ku.dk>',
        ) : () ),
);



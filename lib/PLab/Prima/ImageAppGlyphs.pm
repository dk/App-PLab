package PLab::Prima::ImageAppGlyphs;

package bga;

use constant next           => 0;
use constant prev           => 1;
use constant tile_m         => 2;
use constant cells          => 3;
use constant calcstatistics => 4;
use constant drawprocesses  => 5;
use constant processes      => 6;

package ImageAppGlyphs;

use Prima::StdBitmap;

my $testing = 0;
my $bmImageFile = Prima::Utils::find_image( '', "PLab::Prima::ImageApp.gif");

sub icon  { return Prima::StdBitmap::load_std_bmp( $_[0], 1, 0, $bmImageFile); }
sub image { return Prima::StdBitmap::load_std_bmp( $_[0], 0, 0, $bmImageFile); }

1;

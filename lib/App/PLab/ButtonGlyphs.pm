package App::PLab::ButtonGlyphs;

use Prima;
use Prima::StdBitmap;

my $bmImageFile = Prima::Utils::find_image( '', "App::PLab::ButtonGlyphs.gif");

sub icon { return Prima::StdBitmap::load_std_bmp( $_[0], 1, 0, $bmImageFile); }
sub image{ return Prima::StdBitmap::load_std_bmp( $_[0], 0, 0, $bmImageFile); }


package bg;

use constant abort        => 0;
use constant alarm        => 1;
use constant alarmrng     => 2;
use constant animatn      => 3;
use constant arrow1d      => 4;
use constant arrow1dl     => 5;
use constant arrow1dr     => 6;
use constant arrow1l      => 7;
use constant arrow1r      => 8;
use constant arrow1u      => 9;
use constant arrow1ul     => 10;
use constant arrow1ur     => 11;
use constant arrow2d      => 12;
use constant arrow2l      => 13;
use constant arrow2r      => 14;
use constant arrow2u      => 15;
use constant arrow3d      => 16;
use constant arrow3l      => 17;
use constant arrow3r      => 18;
use constant arrow3u      => 19;
use constant bookopen     => 20;
use constant bookshut     => 21;
use constant brush        => 22;
use constant bulboff      => 23;
use constant bulbon       => 24;
use constant calculat     => 25;
use constant calendar     => 26;
use constant cdrom        => 27;
use constant check        => 28;
use constant clear        => 29;
use constant clock        => 30;
use constant compmac      => 31;
use constant comppc1      => 32;
use constant comppc2      => 33;
use constant copy         => 34;
use constant crdfile1     => 35;
use constant crdfile2     => 36;
use constant crdfile3     => 37;
use constant cut          => 38;
use constant date         => 39;
use constant day          => 40;
use constant delete       => 41;
use constant directry     => 42;
use constant docsingl     => 43;
use constant docstack     => 44;
use constant dooropen     => 45;
use constant doorshut     => 46;
use constant edit         => 47;
use constant erase        => 48;
use constant export       => 49;
use constant fcabopen     => 50;
use constant fcabshut     => 51;
use constant fdrawer1     => 52;
use constant fdrawer2     => 53;
use constant field        => 54;
use constant fileclos     => 55;
use constant filenew      => 56;
use constant fileopen     => 57;
use constant filesave     => 58;
use constant find         => 59;
use constant firstaid     => 60;
use constant fldr2opn     => 61;
use constant fldrmany     => 62;
use constant fldropen     => 63;
use constant fldrshut     => 64;
use constant floppy       => 65;
use constant foldrdoc     => 66;
use constant font         => 67;
use constant fontbold     => 68;
use constant fontital     => 69;
use constant fontsize     => 70;
use constant form         => 71;
use constant gears        => 72;
use constant globe        => 73;
use constant group        => 74;
use constant grphbar      => 75;
use constant grphline     => 76;
use constant grphpie      => 77;
use constant harddisk     => 78;
use constant help         => 79;
use constant helpindx     => 80;
use constant hide         => 81;
use constant hourglas     => 82;
use constant ignore       => 83;
use constant import       => 84;
use constant insert       => 85;
use constant key          => 86;
use constant keyboard     => 87;
use constant led1off      => 88;
use constant led1on       => 89;
use constant led2off      => 90;
use constant led2on       => 91;
use constant led3off      => 92;
use constant led3on       => 93;
use constant library      => 94;
use constant links        => 95;
use constant lockopen     => 96;
use constant lockshut     => 97;
use constant mail         => 98;
use constant mailaud      => 99;
use constant mailbox      => 100;
use constant mailboxf     => 101;
use constant mailhot      => 102;
use constant mailopen     => 103;
use constant mailpict     => 104;
use constant mailtext     => 105;
use constant mailvid      => 106;
use constant many2mny     => 107;
use constant many2one     => 108;
use constant mean         => 109;
use constant median       => 110;
use constant mode         => 111;
use constant monitor      => 112;
use constant mouse        => 113;
use constant music        => 114;
use constant netpeer      => 115;
use constant netserv      => 116;
use constant night        => 117;
use constant npad         => 118;
use constant npadtab      => 119;
use constant npadwrit     => 120;
use constant one2many     => 121;
use constant one2one      => 122;
use constant pagenum      => 123;
use constant paste        => 124;
use constant pencil       => 125;
use constant phone        => 126;
use constant phonerng     => 127;
use constant picture      => 128;
use constant print        => 129;
use constant printer      => 130;
use constant property     => 131;
use constant query        => 132;
use constant report       => 133;
use constant resource     => 134;
use constant retry        => 135;
use constant show         => 136;
use constant sort         => 137;
use constant sound        => 138;
use constant spelling     => 139;
use constant stpwatch     => 140;
use constant sum          => 141;
use constant table        => 142;
use constant time         => 143;
use constant tools        => 144;
use constant trash        => 145;
use constant trashful     => 146;
use constant tutorial     => 147;
use constant undo         => 148;
use constant ungroup      => 149;
use constant variance     => 150;
use constant vcrfsfor     => 151;
use constant vcrpause     => 152;
use constant vcrplay      => 153;
use constant vcrrecrd     => 154;
use constant vcrrewnd     => 155;
use constant vcrstop      => 156;
use constant video        => 157;
use constant watch        => 158;
use constant write        => 159;
use constant zoomin       => 160;
use constant zoomout      => 161;

1;
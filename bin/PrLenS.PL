use Config;
use File::Basename qw(basename dirname);
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
	if ($Config{'osname'} eq 'VMS' or
	    $Config{'osname'} eq 'OS2');  # "case-forgiving"
open OUT,">$file" or die "Can't create $file: $!";
chmod(0755, $file);
print "Extracting $file (with variable substitutions)\n";

print OUT <<"!GROK!THIS!";
$Config{'startperl'} -w

!GROK!THIS!

print OUT <<'!NO!SUBS!';

use strict;
use Prima;
use Prima::Application name => "PrLenS";
use PLab::Prima::ImageApp;
use PLab::Prima::Calibrations;
use IPA::Local;
use IPA::Misc;
use IPA::Point;
use IPA::Global;
use IPA::Morphology;
use IPA::Region;
use Prima::VB::VBLoader;

$::application-> icon( ImageAppGlyphs::icon( bga::processes));


package LenWindow;
use vars qw(@ISA);
@ISA = qw(ImageAppWindow::Calibrations);

sub win_inidefaults
{
   my $w = $_[0];
   return (
      $w-> SUPER::win_inidefaults,
      nLines             => 6,
      autoCrispen        => 0,
      autoStretch        => 0,
      StatisticsWindowRect => '120 120 400 250',
      SpectrumMin        => 0,
      SpectrumMax        => 50,
      ShowExtras         => 0,
      C_minUF            => 1,
      C_maxUF            => 5,
      C_stepUF           => 10,
      C_min_area         => 200,
      C_min_rank         => 1,
      C_max_index        => 255,
      C_min_index        => 60,
      C_dilations        => 2,
      C_erosions         => 1,
      C_cell_radius      => 25,
   );
}


sub on_create
{
   my $self = $_[0];
   my $w    = $_[0];
   $self-> SUPER::on_create;
   $self-> {dataExt}            = 'pls';
   
   my $tb  = $self-> ToolBar;

   my %btn_profile = (
     glyphs      => 1,
     text        => "",
     selectable  => 0,
     transparent => 1,
     flat        => 1,
     size        => [ 36, 36],
     borderWidth => 1,
     enabled     => 0,
   );

   $tb-> insert(
      [ SpeedButton =>
         name    => "MarkCells",
         origin  => [120, 1],
         image   => ImageAppGlyphs::icon( bga::cells),
         onClick => sub { $w-> mark_cells },
         hint    => "Mark cells mode",
         %btn_profile,
      ],
      [ SpeedButton =>
         name    => "MarkProcesses",
         origin  => [160, 1],
         image   => ImageAppGlyphs::icon( bga::processes),
         onClick => sub { $w-> mark_processes} , 
         hint    => "Mark processes mode",
         %btn_profile,
      ],
      [ SpeedButton =>
         name    => "DrawProcesses",
         origin  => [200, 1],
         image   => ImageAppGlyphs::icon( bga::drawprocesses),
         onClick => sub { $w-> draw_processes} ,
         hint    => "Draw processes mode",
         %btn_profile,
      ],
      [ Label =>
         name => "CellsProcesses",
         font => { size => 10, pitch => fp::Fixed}, 
         color => cl::Red,
         origin => [ 249, 8],
	 size   => [ 80, 20],
         transparent => 1,
         text   => "???:???",
	 valignment => ta::Middle,
      ],
      [ Widget => 
          name => "MarkStateEx",
          transparent => 1,
          origin  => [ 336, 8],
          size    => [ 20, 20],
          color   => 0,
          onPaint => sub {
             my ( $self, $canvas) = @_;
             my $c = $self-> color;
             return unless $c;
             $canvas-> color( cl::Black);
             $canvas-> fill_ellipse( 10, 10, 10, 10);
             $canvas-> color( $c);
             $canvas-> fill_ellipse( 10, 10, 8, 8);
          },
      ], 
      [ Label =>
         name => "MarkState",
         autoWidth => 1,
         font => { size => 10, pitch => fp::Variable},  
         transparent => 1,
         color => cl::Black,
         origin => [ 356, 8],
	 height => 20,
	 valignment => ta::Middle,
         onClick => sub {
            if ( ! defined( $w-> { markState}) || $w-> { markState} < 2) {
              $w-> reset_mark_state( $w-> {markState} ? 0 : 1);
            }
         }
      ],
   );
   $w-> menu-> EditAutoCrispening-> checked( $w-> {ini}-> {autoCrispen});
   $w-> menu-> EditAutoStretching-> checked( $w-> {ini}-> {autoStretch});
   $w-> reset_mark_state;
}

sub load_info
{
   my ( $w, $recalculate) = ( $_[ 0], $_[ 1]);
   my ( $cpm) = ( $w-> {cypherMask});
   my $file = $w-> win_extname( $w-> {file});
   $file =~ s/\d{$cpm}(\.pls)$/$1/;
   $w-> {info} = {};
   my $info = $w-> {info};
   $w-> {totalCells} = $w-> {totalProcesses} = $w-> {totalLength} = $w-> {totalBranches} = 0;
   return unless open INFO, $file;
   my ($totalCells,$totalProcesses,$totalBranches,$totalLength) = (0,0,0,0);
   my ( $smin, $smax) = $w-> win_getseriesrange;

   while (<INFO>)
   {
      next if /^$/;
      if ( /^#\*/) {
          /^#\*([^\:]+)\:\s*(.*)$/;
          my ( $field, $value) = ( $1, $2);
          if ( $field =~ /Calibrations/i) {
              my ( $xcalib, $ycalib) = split ' ', $value, 2;
              $xcalib =~ s/^\s*(\S+)\s*$/$1/;
              $ycalib =~ s/^\s*(\S+)\s*$/$1/;
              if ( ( $xcalib =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/) && ( $ycalib =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/)) {
                  $xcalib += .0;
                  $ycalib += .0;
                  if (( $xcalib != $w->{ ini}->{ XCalibration})  ||
                      ( $ycalib != $w->{ ini}->{ YCalibration})) {
                      if ( Prima::MsgBox::message("Image contains calibrations [$xcalib $ycalib] opposite to current [".
                          $w->{ini}->{XCalibration}.' '.$w->{ini}->{YCalibration}.']. '.
                          "Keep current settings?",
                          mb::YesNo|mb::Warning, { buttons => { mb::No => { text => '~Apply new'}}}) == mb::Yes) {
                          $w-> modified( 1);
                      } else {
                          $w->{ini}->{XCalibration} = $xcalib;
                          $w->{ini}->{YCalibration} = $ycalib;
                      }
                  }
              } else {
                  Prima::message("Incorrect Calibrations field value");
              }
          }
      }
      next if /^#/;
      next unless m{^\s*            # optional space
                    (\d+)           # number of cells
                    \s+             # space
                    (\d+)           # number of processes (intersections)
                    \s+             # space
                    (\d\d)          # file number
                    ::              # delimiter
                    ([\d\_\,]*)     # coordinates of cell marks
                    ::              # delimiter
                    ([\d\_\,]*)     # coordinates of processes marks
                    (?:
                    ::              # delimiter
                       ((?:(?:[+-]?)(?=\d|\.\d)\d*(?:\.\d*)?(?:[Ee](?:[+-]?\d+))?\&)?) # average process length
                       ([\d\_\,\+\-]*)
                       # hand-drawn branches
                   )?
                   $}x;
      my ($nc,$np,$fn,$ccm,$cpm,$abl,$cbm) = ($1,$2,$3,$4,$5,$6,$7);
      $abl = '' unless defined $abl;
      $cbm = '' unless defined $cbm;

      $cbm =~ tr[\_][\ ];
      my @branches = split ',', $cbm;
      $abl =~ s{\&$}{};

      $totalCells += $nc;
      $totalProcesses += $np;
      $totalLength += $abl if $abl;
      $totalBranches += scalar( @branches);
      $info-> {$fn} = $_;
      my ( $isCurrentFrame) = $fn == $w-> {fileNum};

      if ( $fn == $smin && !$isCurrentFrame) {
         $ccm =~ tr[\_][\ ];
         my @cells = split ',', $ccm;
         Prima::message("Bad number of cells") if scalar @cells != $nc;

         $cpm =~ tr[\_][\ ];
         my @processes = split ',', $cpm;
         Prima::message("Bad number of processes") if scalar @processes != $np;

         $w-> {exCells} = [@cells];
         $w-> {exProcesses} = [@processes];
         undef @cells;
         undef @processes;
      }
      
      if ( $isCurrentFrame)
      {
         $ccm =~ tr[\_][\ ];
         my @cells = split ',', $ccm;
         Prima::message("Bad number of cells") if scalar @cells != $nc;

         $cpm =~ tr[\_][\ ];
         my @processes = split ',', $cpm;
         Prima::message("Bad number of processes") if scalar @processes != $np;

         $w-> {nCells} = scalar @cells;
         $w-> {nProcesses} = scalar @processes;
         $w-> {cells} = [@cells];
         $w-> {processes} = [@processes];
         undef @cells;
         undef @processes;
      }

      if ( $isCurrentFrame || $recalculate) {
         $w->{ branches} = [] if $isCurrentFrame;
         my ( $pb) = ( []);
         my ( $branch);
         my ( $bnum) = 0;
         foreach $branch ( @branches) {
            $branch =~ s/^((?:[+-]?)(?=\d|\.\d)\d*(?:\.\d*)?(?:[Ee](?:[+-]?\d+))?) ((?:[+-]?)(?=\d|\.\d)\d*(?:\.\d*)?(?:[Ee](?:[+-]?\d+))?)(.*)/$3/;
            my ( $x, $y) = ( int( $1), int( $2));
            $pb->[ $bnum]->[ 0] = [ $x, $y];
            while ( length( $branch) > 0) {
               last unless ( $branch =~ s/^([\+\-]\d+)([\+\-]\d+)//);
               my ( $dx, $dy) = ( $1, $2);
               $x += $dx;
               $y += $dy;
               push @{ $pb->[ $bnum]}, [ $x, $y];
            }
            if ( length( $branch) > 0) {
               Prima::message("Bad branches description format");
            }
            $bnum++;
         }
         $w->{ branches} = $pb if $isCurrentFrame;
         $abl = sprintf "%.3f", $w-> calc_branches_length( $pb);
         $ccm =~ tr[\ ][\_];
         $cpm =~ tr[\ ][\_];
         $cbm =~ tr[\ ][\_];
         $info->{ $fn} = "$nc $np $fn\:\:$ccm\:\:$cpm\:\:$abl\&$cbm\n";
         undef @branches;
      }
   }
   close INFO;
   $w-> {totalCells} = $totalCells;
   $w-> {totalProcesses} = $totalProcesses;
   $w-> {totalLength} = $totalLength;
   $w-> {totalBranches} = $totalBranches;
}

sub save_info
{
   my $w = $_[0];
   return 1 unless $w-> modified;
   my $file = $w-> {file};
   return 1 unless defined $file;
   my $info = $w-> {info};
   return 1 unless defined $info;

   my ( $cpm) = ( $w-> {cypherMask});
   my $infoFile = $w-> win_extname( $w-> {file});
   $infoFile =~ s/\d{$cpm}(\.pls)$/$1/;
   
   if ( defined $w-> {nCells} && defined $w-> {nProcesses} &&
        defined $w-> {cells} && defined $w-> {processes})
   {
      my $pp = join( ',', @{$w-> {processes}});
      my $cc = join( ',', @{$w-> {cells}});
      my $bb = '';
      if ( defined( $w->{ branches}) && ( scalar( @{ $w->{ branches}}) > 0)) {
         $bb = sprintf "%.3f&", $w-> calc_branches_length( $w->{ branches});
         my ( $branch);
         my ( $comma) = '';
         foreach $branch ( @{ $w->{ branches}}) {
            next unless scalar( @{ $branch}) > 1;
            $bb .= $comma;
            my ( $x, $y) = @{ $branch->[ 0]};
            $bb .= "$x\_$y";
            my ( $i);
            for ( $i = 1; $i <= $#{ $branch}; $i++) {
               $bb .= sprintf "%+d%+d", $branch->[ $i]->[ 0] - $x, $branch->[ $i]->[ 1] - $y;
               $x = $branch->[ $i]->[ 0];
               $y = $branch->[ $i]->[ 1];
            }
            $comma = ',';
         }
      }
      $pp =~ tr{\ }{\_};
      $cc =~ tr{\ }{\_};
      
      my $fnx = '%0' . $$w{cypherMask} . 'd';
      $fnx = sprintf $fnx, ( $w-> {fileNum} || 0);
      $info-> {$fnx} = scalar @{$w-> {cells}} . " " . scalar @{$w-> {processes}} . " " .
                        "${fnx}::" . $cc . "::" . $pp . "::" . $bb . "\n";
   }
   unless ( open INFO, ">$infoFile") {
      return 0 if Prima::MsgBox::message_box( $::application-> name,
         "Error saving file $infoFile ($!). Ignore changes?", mb::YesNo|mb::Warning) == mb::No;
      return 1;
   }
   
   unless ( -w INFO) {
      close INFO;
      return 0 if Prima::MsgBox::message_box( $::application-> name,
         "Error saving $infoFile: file is read-only. Ignore changes?", mb::YesNo|mb::Warning) == mb::No;
      return 1;
   }

   print INFO "# Number of Test Lines used (may be incorrect): ", $w-> {ini}-> { nLines}, "\n";
   my $stattext = "#\n " . $w-> generate_statistics_text();
   $stattext =~ s/^/# /gm;
   $stattext .= "# \n";
   print INFO $stattext;
   print INFO "#*Calibrations: $w->{ ini}->{ XCalibration} $w->{ ini}->{ YCalibration}\n";
   foreach ( sort { $a <=> $b } keys %$info)
   {
      print INFO $info-> {$_};
   }
   print INFO $w-> {totalCells} . " " . $w-> {totalProcesses} . " **::" .
         ($w-> {totalCells} ? $w-> {totalProcesses} / $w-> {totalCells} : "NONE") . "::\n";
   close INFO;
   return 1;
}


sub generate_statistics_text {
   my ( $w) = @_;

   my ( $nc, $nb, $sbl) = ( $w->{ nCells}, scalar( @{ $w->{ branches}}),
                            $w-> calc_branches_length( $w->{ branches}));
   my ( $abl) = ( $nb == 0 ? 0 : $sbl / $nb);
   my ( $blr) = ( $nc == 0 ? 0 : $sbl / $nc);

   my ( $tnc, $tnb, $tbl) = ( $w->{ totalCells}, $w->{ totalBranches}, $w->{ totalLength});
   my ( $tabl) = ( $tnb == 0 ? 0 : $tbl / $tnb);
   my ( $tblr) = ( $tnc == 0 ? 0 : $tbl / $tnc);

   my ( $fw) = 10; # Field width

   return sprintf <<STOP_HERE, "This", "Total", "frame", $nc, $tnc, $nb, $tnb, $sbl, $tbl, $abl, $tabl, $blr, $tblr;
                                  %${fw}s  %${fw}s
                                  %${fw}s
Number of cells (NC)            : %${fw}d  %${fw}d
Number of drawn processes (NDP) : %${fw}d  %${fw}d
Length of processes (PL)        : %${fw}.3f  %${fw}.3f
Average process length (PL/NDP) : %${fw}.3f  %${fw}.3f
Process length ratio (PL/NC)    : %${fw}.3f  %${fw}.3f
STOP_HERE
}


sub show_stats {
   my $ww = $_[0];
   my ( $update_window) = $_[ 2];

   return unless defined $ww->{ branches};

   my ( $sd, $norepaint);
   if ( ! ( $sd = eval { $ww->Statistics})) {

      return if $update_window;

      my ( @rect) = split ' ', $ww->{ ini}->{ StatisticsWindowRect};
      $sd = Prima::Window->create(
         name => 'Statistics',
         rect => [ @rect],
         font => {
                  pitch => fp::Fixed,
                 },
         owner => $ww,
         onClose => sub {
            $ww->{ ini}->{ StatisticsWindowRect} = join( ' ', $_[ 0]->rect);
         },
      );

      $sd->insert(
         Button =>
         name => "OK",
         hint       => "Close window",
         text => '~Ok',
         origin => [ 10, 10],
         default => 1,
         modalResult => mb::Ok,
         onClick => sub {
            $_[ 0]->owner->close;
         },
      );

      my @lorig = ( 10, $sd->OK->top + 10);
      my @lsize = ( $sd->width - 20, $sd->height - $sd->OK->top - 20);

      $sd->insert(
         Label =>
         name => 'StatText',
         font => { pitch => fp::Fixed, },
         origin => [ @lorig],
         size => [ @lsize],
         growMode => gm::Client,
         text => $ww-> generate_statistics_text(),
         valignment => ta::Center,
         onSize => sub {
            my @lines = split /\n/, $_[ 0]->text;
            my $ln = scalar( @lines) + 1;
            $_[ 0]->font( height => ( $_[ 0]->height / $ln),
                          pitch => fp::Fixed,
                        ) if $ln != 0;
         },
      );

      $sd-> show;
      $norepaint = 1;
   }

   unless ( $norepaint) {
      $sd->StatText->text( $ww-> generate_statistics_text());
      $sd->repaint;
   }
}

sub file_backup
{
   my $w = $_[0];
   my ( $cpm, $file) = ( $w-> {cypherMask}, $w-> win_extname( $w-> {file}));
   $file =~ s/\d{$cpm}(\.pls)$/$1/;
   return if Prima::MsgBox::message( "Copy $file to $file.bak?", mb::OKCancel) != mb::OK;
   return if -f "$file.bak" and Prima::MsgBox::message( "$file.bak exists. Overwrite?", mb::OKCancel) != mb::OK;
   require File::Copy;
   return if File::Copy::copy( $file, "$file.bak");
   Prima::MsgBox::message( "Error:$!", mb::OK|mb::Error);
}

sub draw_processes {
   my $w = $_[0];
   $w-> done_draw_mode;
   $w->{ binfo}->{ drawMode} = 0;
   undef $w->{ binfo}->{ nearestBranch};
   undef $w->{ binfo}->{ prevActiveRect};
   $w-> reset_mark_state(( defined( $w-> {markState}) && ( $w-> {markState} == 2) ? undef : 2))
      if defined $w-> {file};
   $w-> reset_mark_state( $w, undef) unless defined $w-> {file};
}

sub mark_cells
{
   my $w = $_[0]; 
   $w-> reset_mark_state( 1) if defined $w-> {file};
   $w-> reset_mark_state( undef) unless defined $w-> {file};
}

sub mark_processes
{
   my $w = $_[0];
   $w-> reset_mark_state( 0) if defined $w-> {file};
   $w-> reset_mark_state( undef) unless defined $w-> {file};
}


sub win_newframe
{
   my $w = $_[0];
   $w-> SUPER::win_newframe;
   $w-> {nCells}     = 0;
   $w-> {nProcesses} = 0;
   $w-> {totalCells} = 0;
   $w-> {totalProcesses} = 0;
   $w-> {processes} = [];
   $w-> {exProcesses} = [];
   $w-> {cells} = [];
   $w-> {exCells} = [];
   $w-> {branches} = [];
   $w-> modified(0);
   $w-> reset_mark_state; 
   $w-> {mirrorImage} = undef;
   $w-> {recWindow}-> RestoreBtn-> enabled( 0) if $w-> {recWindow};

   return unless defined $w-> {file};

   $w-> win_extwarn if defined $w-> {ini}-> {path} &&
      defined $w-> {oldPath} && $w-> {oldPath} ne $w-> {ini}-> {path};
   $w-> {oldPath} = $w-> {ini}-> {path};
   $w-> preprocess;
}

sub win_loadfile
{
   my ($w,$file) = @_;
   return 0 unless $w-> SUPER::win_loadfile( $file);
   $w-> update_state;
   return 1; 
}

sub win_newextras
{
   my $w = $_[0];
   $w-> SUPER::win_newextras;

   return unless defined $w-> {file};
   $w-> load_info();
}

sub win_saveframe
{
   my $w = $_[0];
   return $w-> save_info();
}

sub win_closeframe
{
   my $w = $_[0];
   $w-> SUPER::win_closeframe;
   $w-> reset_mark_state;
}


sub win_framechanged
{
   my $w = $_[0];
   $w-> SUPER::win_framechanged;

   my $tb = $w-> ToolBar;
   my $i = $w-> IV-> image;
   my $canApply = defined $i && $i-> type == im::Byte;

   $w-> menu-> FileStats-> enabled( $i);
   $w-> menu-> FileBackup-> enabled( $i);
   $w-> menu-> EditProcess-> enabled( $canApply);   
   $w-> menu-> EditProcessSeries-> enabled( $canApply);   
   $tb-> MarkCells-> enabled( $i);
   $tb-> MarkProcesses-> enabled( $i);
   $tb-> DrawProcesses-> enabled( $i);
   if ( $w-> {recWindow}) {
      my $r = $w-> {recWindow};
      $r-> ApplyBtn-> enabled( $canApply);
      $r-> RestoreBtn-> enabled( $canApply && defined $w-> {mirrorImage});
      $r-> PD1-> enabled( $canApply);
      $r-> PD2-> enabled( $canApply);
      $r-> PD3-> enabled( $canApply);
   }
   $w-> reset_mark_state;
   $w-> update_state;
}


sub reset_mark_state
{
   my ( $w, $state)  = @_;
   unless ( defined $state) {
      my $x = $w-> {markStateX} || 0;
      $state = defined($w-> {file}) ? $x : ( $x | 64);
   }
   my $markState = $w-> ToolBar-> MarkState;
   my $markStateEx =  $w-> ToolBar-> MarkStateEx;
   if ( $state & 64) {
      $markState-> text( "Nothing to mark");
      $markStateEx-> color( 0);
      return;
   }
   if (( $state & 3) == 0) {
      $markState-> text( "Marking processes");
      $markStateEx-> color( $w-> {ini}-> {Color_Processes});
   } elsif (( $state & 3) == 1) {
      $markState-> text( "Marking cells");
      $markStateEx-> color( $w-> {ini}-> {Color_Cells});
   } elsif (( $state & 3) == 2) {
      $markState-> text( "Drawing processes" . ( $w->{ binfo}->{ drawMode} ? " (drawing)" : "")) ;
      $markStateEx-> color( 0);
   }
   $w-> {markStateX} = $state;
   $w-> {markState} = ($state & 64) ? undef : $state;
}


sub initiate_draw_mode 
{
   my ( $w, $x, $y) = @_;
   my $self = $w-> IV;
   return unless ( $w->{ markState} == 2) && ( ! $w->{ binfo}->{ drawMode});
   $w->{ binfo}->{ drawMode} = 1;
   $w->{ binfo}->{ removeLastPoint} = 1;
   $w-> iv_cancelmagnify( $self);
   $self-> capture(1);
   $w->{ binfo}->{ branchNumber} = scalar @{ $w->{ branches}};
   $w->{ branches}->[ $w->{ binfo}->{ branchNumber}]->[ 0] = [ $self-> screen2point( $x, $y)];
   $w-> modified( 1); 
   $w-> reset_mark_state( 2);
}

# Function calculates distance from a point at ( x3, y3)
# to a segment of line defined with coordinates ( x1, y1), ( x2, y2).
sub point_line_distance {
   my ( $x1, $y1, $x2, $y2, $x3, $y3) = @_;
   my ( $c1, $c2);
   my ( $x, $y);
   my ( $d) = -1;

   if ( ( $x1 == $x2) && ( $y1 == $y2)) {
      $d = sqrt( ( $x3 - $x1) ** 2 + ( $y3 - $y1) ** 2);
   }
   else {
      $c1 = ( $x2 - $x1) * $y1 + ( $y1 - $y2) * $x1;
      $c2 = ( $x2 - $x1) * $x3 + ( $y2 - $y1) * $y3;

      if ( $y1 == $y2) {
         $x = $x3;
         $y = $y1;
      }
      else {
         $x = ( $c1 * ( $y1 - $y2) - $c2 * ( $x1 - $x2)) / ( ( $y2 - $y1) ** 2 + ( $x2 - $x1) ** 2);
         $y = - ( ( $c2 + ( $x1 - $x2) * $x) / ( $y1 - $y2));
      }

      ( $x1, $x2) = ( $x2, $x1) unless $x2 >= $x1;
      ( $y1, $y2) = ( $y2, $y1) unless $y2 >= $y1;

      if ( ( $x >= $x1) && ( $x <= $x2)
           && ( $y >= $y1) && ( $y <= $y2)) {
         $d = sqrt( ( $x3 - $x) ** 2 + ( $y3 - $y) **2);
      }
      elsif ( $x < $x1) {
         $d = sqrt( ( $x3 - $x1) ** 2 + ( $y3 - $y1) ** 2);
      }
      else {
         $d = sqrt( ( $x3 - $x2) ** 2 + ( $y3 - $y2) ** 2);
      }
   }

   return $d;
}

sub calc_branch_length {
   my ( $w, $br) = @_;
   my ( $xc, $yc) = ( $w->{ ini}->{ XCalibration}, $w->{ ini}->{ YCalibration});
   my $len = 0;
   my ( $x1,$y1) = @{$br->[0]};
   $x1 *= $xc; $y1 *= $yc;
   for my $c (@$br) {
      my ( $x2,$y2) = @$c;
      $x2 *= $xc; $y2 *= $yc;
      $len += sqrt(($x2-$x1)*($x2-$x1)+($y2-$y1)*($y2-$y1));
      ($x1,$y1)=($x2,$y2);
   }
   return $len;
}

sub calc_branches_length {
   my ( $w, $branches) = @_;
   my $totalLength = 0;
   for my $br ( @{$branches}) {
      $totalLength += $w-> calc_branch_length( $br);
   }
   return $totalLength;
}


sub done_draw_mode {
   my $w = $_[0];
   return unless defined( $w->{ markState}) && ( $w->{ markState} == 2)
       && $w->{ binfo}->{ drawMode};
   $w->{ binfo}->{ drawMode} = 0;
   $w->{ binfo}-> {firstDraw} = 0;
   if ( $w->{ binfo}->{ removeLastPoint}) {
      splice @{ $w->{ branches}->[ $w->{ binfo}->{ branchNumber}]}, -1;
   }
   # removing duplicate sequential point and one point length processes.
   my ( $i, $bn);
   for ( $bn = $#{ $w->{ branches}}; $bn >= 0; $bn--) {
      for ( $i = $#{ $w->{ branches}->[ $bn]} - 1; $i >= 0; $i--) {
         if ( ( $w->{ branches}->[ $bn]->[ $i]->[ 0] == $w->{ branches}->[ $bn]->[ $i + 1]->[ 0])
              && ( $w->{ branches}->[ $bn]->[ $i]->[ 1] == $w->{ branches}->[ $bn]->[ $i + 1]->[ 1])) {
            splice @{ $w->{ branches}->[ $bn]}, $i, 1;
         }
      }
      if ( scalar( @{ $w->{ branches}->[ $bn]}) == 1) {
         splice @{ $w->{ branches}}, $bn, 1;
      }
      else {
         $w->{ totalLength} += $w-> calc_branch_length( $w->{ branches}->[ $bn]);
         $w->{ totalBranches}++;
      }
   }
   $w-> IV-> capture(0);
   $w-> reset_mark_state( 2);
   $w-> IV-> repaint;
}

sub preprocess
{
   my $w = $_[0];
   return unless defined $w-> {file};
   my $self = $w-> IV;
   $w-> {preprocessedImage} = $w-> {ini}-> {autoCrispen} ? IPA::Local::crispening( $self-> image) : undef;
   if ($w-> {ini}-> {autoStretch}) {
      my $i = $w-> {preprocessedImage} || $self-> image;
      $w-> {preprocessedImage} = $i-> dup;
      my ( $lo, $hi, $min, $max) = ( $i-> rangeLo, $i-> rangeHi, $w-> {ini}-> {SpectrumMin}, $w-> {ini}-> {SpectrumMax});
      my $lo1 = ( $lo > $min ) ? $min : $lo;
      my $hi1 = ( $hi < $max ) ? $hi : $max;
      $w-> {preprocessedImage}-> resample( $lo1, $hi1, 0, 255);
   }
}


sub crispen_state_changed
{
   my $w = $_[0];
   $w-> {ini}-> {autoCrispen} = $w-> menu-> EditAutoCrispening-> toggle;
   $w-> preprocess;
   $w-> IV-> repaint;
}

sub stretching_state_changed
{
   my $w = $_[0];
   $w-> {ini}-> {autoStretch} = $w-> menu-> EditAutoStretching-> toggle;
   $w-> preprocess();
   $w-> IV-> repaint;
}

sub win_entersubplace
{
   my $w = $_[0];
   $w-> {savePointer} = $::application-> pointer;
   $::application-> pointer( cr::Wait);
   return defined $w-> {mirrorImage} ? $w-> {mirrorImage} : $w-> IV-> image;
}

sub win_leavesubplace
{
   my $w = $_[0];
   $::application-> pointer( $w-> {savePointer});
   $w-> {mirrorImage} = $w-> IV-> image unless defined $w-> {mirrorImage};
   $w-> IV-> image( $_[1]);
   $w-> {recWindow}-> RestoreBtn-> enabled( 1) if $w-> {recWindow};
   $w-> {savePointer} = undef;
   $w-> sb_text('Done');
}

sub win_restore
{
   my ( $w, $i) = @_;
   $w-> IV-> repaint, return unless defined $w-> {mirrorImage};
   $w-> IV-> image($w-> {mirrorImage});
   $w-> {mirrorImage} = undef;
   $w-> {recWindow}-> RestoreBtn-> enabled( 0) if $w-> {recWindow};
}


sub process
{
   my $w = $_[0];
   my $mode = $_[2] || 0;
   $w-> win_rec_updatevalues;
   my $orgi = $w-> win_entersubplace;

   my ( $minUF, $maxUF, $stepUF, $min_area, $min_rank, $max_index, $min_index, $dilate, $erode, $rad) = 
      map { $w-> {ini}-> {$_}} qw(
        C_minUF C_maxUF C_stepUF C_min_area C_min_rank C_max_index C_min_index C_dilations C_erosions C_cell_radius
   );

   my $i = $orgi-> dup;
   my $dd = $dilate;
   $i = IPA::Morphology::dilate( $i) while $dd--;
   return $w-> win_leavesubplace( $i) if $mode == 1;

   my ( $pct, $step) = (0, 100 / (($maxUF - $minUF) * 3 + 2 * 3));
   $pct -= $step;

   # union find
   my @mp = map { 
      my $st = $_;
      #$w-> sb_text( sprintf( "Union find: %d%%", ($st - $minUF)*100/($maxUF-$minUF)));
      $w-> sb_text( sprintf( "%d%% ( union find )", $pct += $step));
      $_ = IPA::Local::unionFind( $i, method => 'ave', threshold => $st * $stepUF); 
   } $minUF .. $maxUF;

   # contour find
   my $num = 0;
   my $sz = $i-> width * $i-> height;
   my @co;
   my $contnum = 0;
   for ( @mp) {
      $num++;
      $w-> sb_text( sprintf( "%d%% ( contour find )", $pct += $step));
      my $img = $_;
      my @hist = IPA::Misc::histogram( $_);
      my @srt_hist = sort { $b <=> $a } @hist;
      my $max_bkg  = $srt_hist[0] * 0.8;

      my $cou = {};
      my $j;

      my @map = map { ($hist[$_] > $max_bkg) ? 0 : 255} (0..255);
      $map[0] = 255 if $hist[0] < $max_bkg; # if 0 is valid
#     for ( 0..255) {
#        $map[$_] = ( $_ < $min_index || $_ > $max_index) ? 0 : $map[$_];
#     }
      $img = IPA::Point::remap( $img, lookup => \@map);
      $img = IPA::Global::fill_holes( $img);
      $img = IPA::Global::area_filter( $img, minArea => $min_area, maxArea => $sz);
      $cou = [map { IPA::Region::contour2region($_)} @{IPA::Global::identify_contours( $img, edgeSize => 1)}];
      push @co, $cou;
   }

   
   # Contour link

   my $l;
   my @kgraph;
   for ( $l = 0; $l < @co - 1; $l++) { # frame cycle
      $w-> sb_text( sprintf( "%d%% ( contour link )", $pct += $step ));
      my ( $co1, $co2) = ( $co[$l], $co[$l+1]);
      my @klayer = ();
      my $src_contour = $co1;
      my $kid = -1;
      for ( @$src_contour) {
         my $k;
         my ( $min_diff, $best_contour, $best_outline, $src)  = ( 1_000_000_000, undef, undef, $_);
         my $kid2 = -1;
         for ( @$co2) {
            $kid2++;
            my $cnt_diff = IPA::Region::combine( $src, $_, 'and');
            $cnt_diff = $cnt_diff->[2] ? $cnt_diff->[2] : 1_000_000_001; # hacky interconnection ratio
            next if $cnt_diff > $min_diff;
            $min_diff = $cnt_diff;
            $best_contour = $kid2;
            $best_outline = $_;
         }
         $kid++;
         next unless defined $best_outline;
         push @klayer, {
            id   => [ $kid, $best_contour], # used as unique ID for matching
            out  => [ $src, $best_outline], # just outlines
            rank => 0,  # chain length,
            top  => 1,  # if the link is a tree top?
            branches => [],
         };
      }
      push @kgraph, \@klayer;
   }
   
   
#  $w-> sb_text( "Line up contours");
   $w-> sb_text( sprintf( "%d%% ( line up contours )", $pct += $step));
   for ( $l = @kgraph - 2; $l >= 0; $l--) { # layer cycle from top to bottom
      for ( @{$kgraph[ $l]}) { # every contour hash in the layer
         my $src_cont = $_;
         for ( @{$kgraph[ $l + 1]}) { # match to upper every at the upper layer
            my $dst_cont = $_;
            my $r = $src_cont->{rank} + 1;
            if ( $src_cont->{id }->[$r] == $dst_cont->{id }->[0]) {
                 my ( $i, $j) = ( 1, $r + 1);
                 for ( ; $j <= $r + 1 + $dst_cont->{rank}; $j++, $i++) { # for every uplink
                    $src_cont->{id }->[$j] = $dst_cont->{id} ->[$i];
                    $src_cont->{rank}++;
                 }
                 $src_cont->{top} = 0;
                 $src_cont->{uplink} = $dst_cont;
                 push @{$dst_cont->{branches}}, $src_cont;
                 last;
            }
         }
      }
   }
   
   # $w-> sb_text( "Finalizing output...");
   $w-> sb_text( sprintf( "%d%% ( bulk mask )", $pct += $step));
   my $kk; 
   $kk = Prima::Image-> create( width => $i-> width, height => $i-> height, type => im::BW);
   $kk-> begin_paint;
   $kk-> backColor( 0);
   $kk-> clear;
   $kk-> color( cl::White);
   for ( map { @$_} @kgraph) {
      my $x = $_;
      next if !$x->{top};
      my $rank = $x-> {rank};
      my @z = @{$x->{branches}};
      while ( scalar @z) {
         @z = map {@{$_->{branches}}} @z;
         $rank++;
      }
      next if $rank < $min_rank;
      my ( $clx, $a1, $a2, $a3) = ( 0, 0, 0, 0);
      for ( @{$x->{out}}) {
         IPA::Region::plot( $kk, $_);
         $a1++;
      }
      @z = @{$x->{branches}};
      while ( scalar @z) {
         for ( @z) {
            $a3++;
            for ( @{$_->{out}} ) {
               IPA::Region::plot( $kk, $_);
               $a2++;
            }
         }
         @z = map {@{$_->{branches}}} @z;
      }
      $l++;
   }

   $kk-> end_paint;
   $kk-> type( im::Byte);
   $w-> sb_text( sprintf( "%d%% ( filter mask )", $pct += $step));
   $kk = IPA::Global::fill_holes( $kk);
   $dd = $dilate;
   $kk = IPA::Morphology::erode( $kk) while $dd--;
   $kk = IPA::Global::area_filter( $kk, minArea => $min_area, maxArea => $sz);
   return $w-> win_leavesubplace( $kk) if $mode == 2;
   $w-> sb_text( sprintf( "%d%% ( find centroids )", $pct += $step));

   sub weigh_center
   {
      my $c = $_[0];
      my @a = ([], []);
      my $flip = 0;
      for ( @$c) {
         push @{$a[$flip]}, $_;
         $flip = $flip ? 0 : 1;
      }
      @{$a[0]} = sort { $a <=> $b } @{$a[0]};
      @{$a[1]} = sort { $a <=> $b } @{$a[1]};
      return ( $a[0]->[scalar(@{$a[0]})/2], $a[1]->[scalar(@{$a[1]})/2]);
   }

   # the contours are up - finding 'centroids' and doing stereology
   my $conto = IPA::Global::identify_contours( $kk);
   my $mask  = $kk-> dup;
   my @centroids;
   my @processes;
   my @excl = map { int( $_ - $_ / 20) } $kk-> size;

   sub excluded  # find if a contour touches the exclusion borders
   {
      my $flip = 0;
      my @excl = @_[1,2];
      for ( @{$_[0]}) {
         return 1 if $_ >= $excl[ $flip];
         $flip = $flip ? 0 : 1;
      }
      return 0;
   }

   if ( $mode == 3) {
      $kk-> begin_paint;
      $kk-> color(0);
      $kk-> bar( 0, 0, $kk-> size);
      $kk-> rop( rop::OrPut);
   }

   my ( $ww, $hh) = $mask-> size;
   my $ls = int(( $ww * 8 + 31) / 32) * 4;
   my $dy = int($hh / 20);
   my $szy = int(($hh - 2 * $dy) / $w-> {ini}-> {nLines});
   
   for ( @$conto) {
      next if excluded( $_, @excl);
   
      $mask-> begin_paint;
      $mask-> set( color => cl::White, backColor => cl::Black);
      $mask-> clear;
      $mask-> fillpoly( $_);
      $mask-> end_paint;

      $mask-> type( im::Byte);
      $dd = $erode;
      $mask = IPA::Morphology::erode( $mask) while $dd--;
     
      my $z = IPA::Point::mask( $mask, test => 255, match => $orgi, mismatch => 0);
      my @h = IPA::Misc::histogram( $z);
      my ( $i, $mean) = (0,0);
      $mean += $i++ * $_ for @h;
      $i = 0;
      shift @h;
      $i += $_ for @h;
      $mean /= ( $i ? $i : 1);

      my ( $x, $y) = weigh_center( $_);
      if ( $mode == 3) {
         $kk-> color(($mean < $min_index || $mean > $max_index) ? cl::LightRed : cl::LightGreen);
         $kk-> put_image( 0,0,$mask);
         $kk-> text_out( sprintf("%d", $mean), $x+5, $y+5);
      }
      
      next if $mean < $min_index || $mean > $max_index;
      push @centroids, "$x $y";

      $mask = IPA::Morphology::thinning( $mask);
      my $d = $mask-> data;
      my $mm = 0;
      for ( $i = 1; $i <= $w-> {ini}-> {nLines}; $i++) {
         my $ay = $dy + $i * $szy;
         unless ( $mm) {
            $mm = 1, next if $ay > $y - $rad && $ay < $y + $rad;
         }
         my $scanline = substr( $d, $ls * $ay, $ww);
         my $ax = 0;
         my @localp;
         $scanline =~ s/(?:(\0+)|(.))/push(@localp, $ax) if $2; $ax += length($1||$2); ' '/xeg;
         my $prev = -$rad * 2;
         push @processes, map {"$_ $ay"} grep {
            my $yes = ( $prev + $rad < $_);
            $prev = $_;
            $yes;
         } grep { 
            $mm ? 1 : ( $mm = 1, $_ <= $x - $rad || $_ >= $x + $rad )
         } @localp;
      }
   }

   if ( $mode == 3) {
      $kk-> end_paint;
      $w-> win_leavesubplace( $kk);
      return;
   }

   $w-> {totalCells} -= $w-> {nCells};
   $w-> {cells}  = \@centroids;
   $w-> {nCells} = scalar( @centroids);
   $w-> {totalProcesses} -= $w-> {nProcesses};
   $w-> {processes} = \@processes;
   $w-> {nProcesses} = scalar( @processes);
   

   $w-> IV-> repaint;
   $w-> modified(1);
   $w-> update_state;
   $::application-> pointer( $w-> {savePointer});
   $w-> {savePointer} = undef;
}

sub process_series
{
   my $w = $_[0];
   Prima::MsgBox::message( "No series to process"), return if ( !defined $w-> {nextFile} && !defined $w-> {prevFile});
   my $num = $w-> {cypherMask};
   my ( $fn, $tn) = $w-> win_getseriesrange;
   return if Prima::MsgBox::message( "This will process series ".
      $w-> {fileBeg}.('X' x $num).$w-> {fileEnd}." [$fn-$tn] . Proceed?",
      mb::OKCancel|mb::Information) != mb::OK;
   my $fnsave = $w->{fileNum};
   my $f;   
   my $ok = 1;
   $w->{packetAborted} = 0;

   my $userAborted = 0;
   my $statwin = $w-> insert( Dialog =>
      centered    => 1,
      text        => 'Processing',
      size        => [ 300, 60],
      onKeyDown   => sub {
         my ( $self, $code, $key, $mod) = @_;
         if ( $key == kb::Esc &&
            ( Prima::MsgBox::message("Abort process?", mb::OKCancel|mb::Warning) == mb::OK)) {
            $userAborted = 1;
            $_[0]-> text('Cancelling');
         }
      },
      onClose     => sub {
         $_[0]-> clear_event;
         return if Prima::MsgBox::message("Abort process?", mb::OKCancel|mb::Warning) != mb::OK;
         $userAborted = 1;
         $_[0]-> text('Cancelling');
      },
   );

   my $g = $statwin-> insert( Gauge =>
      origin => [ 5, 5],
      size   => [ $statwin-> width - 10, $statwin-> height - 10],
      min    => $fn,
      max    => $tn,
      value  => $fn,
      font   => {height => $statwin-> height - 16},
   );
   

   $statwin-> execute_shared;
   for my $i ( $fn..$tn) {
       $f = sprintf( "%s%0${num}d%s",$w->{fileBeg}, $i, $w-> {fileEnd});
       $::application-> yield;
       $ok = 0, last, if $userAborted;
       if ( !$w-> win_loadfile( $f) || $w->{packetAborted}) {
          Prima::MsgBox::message("Aborted - error processing file $f", mb::OK|mb::Error);
          $ok = 0;
          last;
       }
       $w-> process('', 0);
       $g-> value( $i);
   }
   $statwin-> destroy;
   
   if ( $ok) {
      Prima::MsgBox::message("Queue processed", mb::OK|mb::Information);
      $w->win_loadfile( sprintf( "%s%0${num}d%s",$w->{fileBeg}, $fnsave, $w-> {fileEnd}));
   }
}

sub win_rec_updatevalues
{
   my $w = $_[0];
   return unless $w-> {recWindow};
   my ( $r, $i) = ( $w-> {recWindow}, $w-> {ini});
   $i-> {C_minUF}     = $r-> UF-> From-> value;
   $i-> {C_maxUF}     = $r-> UF-> To-> value;
   $i-> {C_stepUF}    = $r-> UF-> Step-> value;
   $i-> {C_min_index} = $r-> FLT-> Min-> value;
   $i-> {C_max_index} = $r-> FLT-> Max-> value;
   $i-> {C_min_area}  = $r-> Area-> value;
   $i-> {C_dilations} = $r-> Dilations-> value;
   $i-> {C_erosions}  = $r-> Erosions-> value;
   $i-> {C_cell_radius}  = $r-> Radius-> value;
}

sub win_showrec
{
  my $w = $_[0];
  unless ( $w-> {recWindow}) {
     my $fi = Prima::find_image( '', 'PLab::Prima::prlens.fm');
     unless ( defined $fi) { Prima::message( "Cannot find resource: PLab::Prima::prlens.fm"); return }
      eval { $w-> {recWindow} = { Prima::VB::VBLoader::AUTOFORM_CREATE( $fi,
         Form1 => {
            onClose => sub { 
               $w-> win_rec_updatevalues;
               $w-> {recWindow} = undef; 
            },
         },
         ApplyBtn   => { onClick => sub { $w-> process('', 0)}},
         PD1        => { onClick => sub { $w-> process('', 1)}},
         PD2        => { onClick => sub { $w-> process('', 2)}},
         PD3        => { onClick => sub { $w-> process('', 3)}},
         RestoreBtn => { onClick => sub { $w-> win_restore; }},
      )}-> {Form1}};
     if ( $@) { Prima::message("Error in setup resource: $@"); return };
     my ( $r, $i) = ( $w-> {recWindow}, $w-> {ini});
     $r-> UF-> From-> value ($i-> {C_minUF}   ); 
     $r-> UF-> To-> value   ( $i-> {C_maxUF}  );
     $r-> UF-> Step-> value ($i-> {C_stepUF}  );
     $r-> FLT-> Min-> value ($i-> {C_min_index});
     $r-> FLT-> Max-> value ($i-> {C_max_index});
     $r-> Area-> value      ( $i-> {C_min_area});
     $r-> Dilations-> value ($i-> {C_dilations});
     $r-> Erosions-> value  ( $i-> {C_erosions});
     $r-> Radius-> value  ( $i-> {C_cell_radius});
     $w-> win_framechanged;
  }
  $w-> {recWindow}-> bring_to_front;
  $w-> {recWindow}-> select;
}


sub IV_MouseDown
{
   my ( $w, $self, $btn, $mod, $x, $y) = @_;
   if ( ( ( $btn & mb::Left) == mb::Left)
           && ( defined $w->{ markState}) && ( $w->{ markState} == 2)
           && ( ( ! defined $w->{ binfo}) || ( ! $w->{ binfo}->{ drawMode}))) {
       $w-> initiate_draw_mode( $x, $y); 
       $self-> clear_event;
       return;
   }

   if ( $btn == mb::Right && !( $mod & km::Ctrl)) 
   {
      if ( ! defined( $w-> { markState}) || $w-> { markState} < 2)
      {
         if ( $w-> {markState})
         {
            $w-> reset_mark_state( 0);
         }
         else
         {
            $w-> reset_mark_state( 1);
         }
      }
      else {
         if ( $w->{ binfo}->{ drawMode}) {
            $w-> done_draw_mode();
         }
         elsif ( defined( $w->{ binfo}->{ nearestBranch})) {
            $w->{ totalLength} -= $w-> calc_branch_length( $w->{ branches}->[ $w->{ binfo}->{ nearestBranch}]);
            $w->{ totalBranches}--;
            splice @{ $w->{ branches}}, $w->{ binfo}->{ nearestBranch}, 1;
            $w->{ binfo}->{ nearestBranch} = undef;
            $w-> modified( 1); 
            $self-> repaint;
         }
         $w-> show_stats( undef, 1);
      }
      $self-> clear_event;
      return;
   }
   
   if ( $btn == mb::Right && ($mod & km::Ctrl)) {
      $mod &= !km::Ctrl;
   }
   $w-> SUPER::IV_MouseDown( $self, $btn, $mod, $x, $y); 
}

sub IV_MouseMove
{
   my ( $w, $self, $mod, $x, $y) = @_;
   
   $w-> SUPER::IV_MouseMove( $self, $mod, $x, $y);

   return if !defined $w-> {binfo} || !defined $w-> {markState} || $w-> {markState} != 2;

   if ( $w->{ binfo}->{ drawMode} == 1) {
      my ( $bn) = $w->{ binfo}->{ branchNumber};
      my ( $ox, $oy) = @{ $w->{ branches}->[ $bn]->[ -1]};
      my ( $ax, $ay) = $self-> screen2point( $x, $y);
      my ( $ms) = $self->get_mouse_state;
      if ( ( scalar( @{ $w->{ branches}->[ $bn]}) == 1) || ( ( $ms & mb::Left) == mb::Left)) {
         push @{ $w->{ branches}->[ $bn]}, [ int($ax), int($ay)];
         $w->{ binfo}->{ removeLastPoint} = 0;
         $w-> {binfo}-> {firstDraw} = 1;
      }
      else {
         return unless $w-> {binfo}-> {firstDraw};
         @{ $w->{ branches}->[ $bn]->[ -1]} = ( $ax, $ay);
         $w->{ binfo}->{ removeLastPoint} = 1;
      }
      if ( scalar( @{ $w->{ branches}->[ $bn]}) > 1) {
         my ( $ex, $ey) = @{ $w->{ branches}->[ $bn]->[ -1]};
         my ( $bx, $by) = @{ $w->{ branches}->[ $bn]->[ -2]};
         my ( $left, $bottom, $right, $top) = ( $ox, $oy, $ox, $oy);
         $left = $ex if $left > $ex;
         $left = $bx if $left > $bx;
         $bottom = $ey if $bottom > $ey;
         $bottom = $by if $bottom > $by;
         $right = $ex if $right < $ex;
         $right = $bx if $right < $bx;
         $top = $ey if $top < $ey;
         $top = $by if $top < $by;
         $self-> invalidate_rect( $self-> point2screen( $left, $bottom, $right + 1, $top + 1));
      }
   }
   else{
      my ( $mindist, $bn, $i);
      my ( $rr);
      for ( $i = 0; $i <= $#{ $w->{ branches}}; $i++) {
         my ( $lmd, $j);
         my ( $left, $bottom, $right, $top) = ( @{ $w->{ branches}->[ $i]->[ 0]}, @{ $w->{ branches}->[ $i]->[ 0]});
         for ( $j = 0; $j < $#{ $w->{ branches}->[ $i]}; $j++) {
            my ( $x1, $y1, $x2, $y2) = ( @{ $w->{ branches}->[ $i]->[ $j]},
                                         @{ $w->{ branches}->[ $i]->[ $j + 1]});
            my ( $dist) = point_line_distance( $x1, $y1, $x2, $y2, $self-> screen2point($x, $y));
            $lmd = $dist unless defined $lmd;
            $lmd = $dist if $lmd > $dist;
            $left = $x1 if $left > $x1;
            $left = $x2 if $left > $x2;
            $bottom = $y1 if $bottom > $y1;
            $bottom = $y2 if $bottom > $y2;
            $right = $x1 if $right < $x1;
            $right = $x2 if $right < $x2;
            $top = $y1 if $top < $y1;
            $top = $y2 if $top < $y2;
         }
         if ( ( ! defined( $mindist)) || ( $mindist > $lmd)) {
            $mindist = $lmd;
            $bn = $i;
            $rr = [ $left, $bottom, $right + 1, $top + 1];
         }
      }
      if ( defined( $mindist) && ( $mindist <= 10)) {
         if ( ( ! defined( $w->{ binfo}->{ nearestBranch})) || ( $w->{ binfo}->{ nearestBranch} != $bn)) {
            $w->{ binfo}->{ nearestBranch} = $bn;
            $self-> invalidate_rect( $self-> point2screen( @{ $w->{ binfo}->{ prevActiveRect}})) 
               if defined $w->{ binfo}->{ prevActiveRect};
            $self->invalidate_rect( $self-> point2screen( @$rr));
            $w->{ binfo}->{ prevActiveRect} = $rr;
         }
      }
      elsif ( defined $w->{ binfo}->{ nearestBranch}) {
         undef $w->{ binfo}->{ nearestBranch};
         $self->invalidate_rect( $self-> point2screen( @{ $w->{ binfo}->{ prevActiveRect}}))
            if defined $w->{ binfo}->{ prevActiveRect};
         undef $w->{ binfo}->{ prevActiveRect};
      }
   }
}

sub IV_MouseClick
{
   my ( $w, $self, $btn, $mod, $x, $y, $dbl) = @_;
   
   $self-> clear_event;
   return unless defined $w-> {file};

   return unless $btn == mb::Left;
   return unless defined $w-> {markState};
   my ( $ax, $ay) = $self-> screen2point( $x, $y);
   return unless ( $ax >= 0 && $ay >= 0 && $ax < $w->{IVx} && $ay < $w->{IVy});
   my $ary = undef;
   $ary = $w-> {processes} if $w-> {markState} == 0;
   $ary = $w-> {cells}     if $w-> {markState} == 1;
   $ary = $w-> {branches}  if $w->{ markState} == 2;
   return unless defined $ary;

   if ( $w->{ markState} == 2) {
      if ( ! $w->{ binfo}->{ drawMode}) {
         $w-> initiate_draw_mode( $x, $y);
      }

      my ( $bn) = $w->{ binfo}->{ branchNumber};
      push @{ $w->{ branches}->[ $bn]}, [ int($ax), int($ay)];
      $w->{ binfo}->{ removeLastPoint} = 1;
      $w-> modified(1);
   }
   else {
      my ($i,$x1,$x2,$y1,$y2);


      # search for an existing point
      for ( $i = 0; $i < scalar @$ary; $i++)
      {
         ($x1,$y1) = split ' ', $$ary[$i];
         ($x2,$y2) = map { $_ + 6; } ($x1,$y1);
         ($x1,$y1) = map { $_ - 6; } ($x1,$y1);
         last if $ax >= $x1 && $ax <= $x2 && $ay >= $y1 && $ay <= $y2;
      }

      $w-> modified( 1); 
      if ( $i < scalar @$ary)
      {
         # removing existing point
         ($ax, $ay) = split(' ', splice( @$ary, $i, 1));
         $w-> {nCells}-- if $w-> {markState} == 1;
         $w-> {nProcesses}-- if $w-> {markState} == 0;
         $w-> {totalCells}-- if $w-> {markState} == 1;
         $w-> {totalProcesses}-- if $w-> {markState} == 0;
      }
      else
      {
         # adding new point
	 $ax = int($ax);
	 $ay = int($ay);
         push @$ary, "$ax $ay";
         $w-> {nCells}++ if $w-> {markState} == 1;
         $w-> {nProcesses}++ if $w-> {markState} == 0;
         $w-> {totalCells}++ if $w-> {markState} == 1;
         $w-> {totalProcesses}++ if $w-> {markState} == 0;
      }
      ($x1, $x2, $y1, $y2) = map { ($_ - 6, $_ + 6); } ($ax,$ay);
      $self-> invalidate_rect( $self-> point2screen( $x1, $y1, $x2, $y2));
   }
   $w-> update_state;
}

sub update_state
{
   my $w = $_[0];
   my $cp = $w-> ToolBar-> CellsProcesses;
   if ( !defined $w-> {file})
   {
      $w-> sb_text( "No file loaded");
      $cp-> text( "???:???");
   }
   else
   {
      $w-> sb_text( "Cells: ". $w-> {nCells} . "(" . $w-> {totalCells} . ")" .
                     ",   Processes: ". $w-> {nProcesses} . "(" . $w-> {totalProcesses} . ")" .
                     ",   Ratio: " . ($w-> {totalCells} ? $w-> {totalProcesses} / $w-> {totalCells} : "NONE")
      );
      $cp-> text( sprintf( "%03d:%03d", $w-> {nCells}, $w-> {nProcesses}));
   }
   $w-> show_stats( undef, 1);
}


sub IV_Paint
{
   my ( $w, $self, $canvas) = @_;

   my $image = $self-> {image};
   $self-> {image} = $w-> {preprocessedImage} if $w-> {preprocessedImage};
   $self-> on_paint( $canvas);
   $self-> {image} = $image;

   return unless $image;
   
   my $z  = $self-> zoom;
   my $zp = ( $z < 1) ? 4 : $z * 4;
   $canvas-> transform( $self-> point2screen( 0, 0));
   my ($x, $y, $iw, $ih) = ( $self-> size, $image-> size);
   my $dx = sprintf( '%d', $iw / 20);
   my $dy = sprintf( '%d', $ih / 20);
   my $szy = sprintf( '%d', ($ih - 2 * $dy) / $w-> {ini}-> {nLines});

   $dx *= $z;
   $dy *= $z;
   $iw *= $z;
   $ih *= $z;
   $szy *= $z;
   
   $canvas-> set( lineWidth => 2, color => $w-> {ini}-> {Color_Frame});
   $canvas-> line( $dx, $dy, $iw - $dx, $dy);
   $canvas-> line( $iw - $dx, $dy, $iw - $dx, 0);
   $canvas-> line( $dx, $dy, $dx, $ih);
   $canvas-> linePattern( lp::LongDash);
   $canvas-> line( $dx, $ih - $dy, $iw - $dx, $ih - $dy);
   $canvas-> line( $iw - $dx, $ih - $dy, $iw - $dx, $dy);
   $canvas-> set( lineWidth => 1, linePattern => lp::Solid);
   for ( my $i = 1; $i < $w-> {ini}-> {nLines}; $i++) {
      $canvas-> line( $dx, $dy + $szy*$i, $iw - $dx, $dy + $szy*$i);
   }

   $canvas-> color( $w-> {ini}-> {Color_Cells});
   
   foreach (@{$w-> {cells}}) {
      my ($x, $y) = split;
      $canvas-> fill_ellipse( $x * $z, $y * $z, $zp, $zp);
   }
   if ( $w-> {ini}-> {ShowExtras}) {
      foreach (@{$w-> {exCells}}) {
         my ($x, $y) = split;
         $x *= $z; $y *= $z;
         $canvas-> line( $x - 3, $y - 3, $x + 3, $y + 3);
         $canvas-> line( $x - 3, $y + 3, $x + 3, $y - 3);
      }
   }
   

   $canvas-> color( $w-> {ini}-> {Color_Processes});
   foreach (@{$w-> {processes}})
   {
      my ($x, $y) = split;
      $canvas-> fill_ellipse( $x * $z, $y * $z, $zp, $zp);
   }
   if ( $w-> {ini}-> {ShowExtras}) {
      foreach (@{$w-> {exProcesses}}) {
         my ($x, $y) = split;
         $x *= $z; $y *= $z;
         $canvas-> line( $x - 3, $y - 3, $x + 3, $y + 3);
         $canvas-> line( $x - 3, $y + 3, $x + 3, $y - 3);
      }
   }   

   my $lw = $canvas->lineWidth;
   $canvas->lineWidth( 1);
   my ( $i) = 0;
   foreach ( @{ $w->{ branches}}) {
      if ( defined( $w->{ binfo}->{ nearestBranch}) && ( $i == $w->{ binfo}->{ nearestBranch})) {
         $canvas->color( $w->{ini}-> {Color_ActiveProcess});
      }
      else {
         $canvas->color( $w-> {ini}-> {Color_Branches});
      }
      my ( @br) = map { ( $_->[ 0] * $z, $_->[ 1] * $z)} @$_;
      $canvas->polyline( \@br);
      $i++;
   }
   $canvas->lineWidth( $lw);
}

# OPT

sub opt_colors
{
   return {
      'Frame'         => [ cl::LightMagenta, 'Frame'],
      'Processes'     => [ cl::Blue,       'Process'],
      'Branches'      => [ cl::LightGreen, 'Branches'],
      'ActiveProcess' => [ 0x80FF80,       'Active process'],
      'Cells'         => [ cl::LightRed,   'Cells'],
   };
}

sub opt_keys
{
   return {
      %{$_[0]-> SUPER::opt_keys()},
      EditAutoCrispening => [ kb::Space,           'Automatically crispen the image'],
      EditAutoStretching => [ km::Ctrl|kb::Space,  'Automatically stretch the image color spectrum'],
      EditProcess        => [ '^A',                'Markup processes automatically'],
      EditProcessSeries  => [ kb::NoKey,           'Markup series of processeses automatically'],
      EditRecSetup       => [ '@R',                'Display recognition setup dialog'],
      FileStats          => [ '@S',                'Invoke statistic data dialog'],
      FileBackup         => [ kb::NoKey,           'Backup current series data'],
      HelpAbout          => [ kb::NoKey,           'Standard about box'],
      HelpPlabApps       => [ kb::NoKey,           'Online PlabApps overview'],
      HelpContents       => [ kb::NoKey,           'Online PrLenS overview'],
   },
}

sub opt_propcreate
{
   my ( $w, $dlg, $nb, $nbpages) = @_;
   $w-> SUPER::opt_propcreate( $dlg, $nb, $nbpages);
   $nb-> tabs( @{$nb-> tabs}, 'Stretching');
   $nb-> insert_to_page( 1, [ SpinEdit =>
       origin => [ 10, 105],
       width  => 120,
       name   => 'nLines',
       min    => 2,
       max    => 20,
       hint   => 'Amount of lines in the grid',
   ] , [ Label =>
       origin => [ 10, 125],
       width  => 120,
       autoWidth => 1,
       text   => 'Number of lines',
   ], [ CheckBox => 
       origin  => [ 10, 155],
       size    => [ 374, 36], 
       name    => 'ShowExtras',
       text    => '~Show extra markings',
       hint    => "If on, the markings on the first image in the series\nwill be displayed as crosses",
   ]);
   my $slider = $nb-> insert_to_page( 4, [ Widget => 
       origin  => [ 20, 70],
       size    => [ 262, 100],
       name    => 'StretchSlider',
       designScale => undef,
       onCreate => sub { 
          ( $_[0]-> {min}, $_[0]-> {max}) = (0,255);
       },
       onPaint => sub {
          my ( $self, $canvas) = @_;
          my ( $a, $b) = ($self-> {min}, $self-> {max});
          my @sz = $self-> size;
          $canvas-> color( cl::Black);
          $canvas-> rectangle( 0, 0, $sz[0]-1, $sz[1]-1);
          $canvas-> bar( 1, 1, 2, $sz[1]-2);
          $canvas-> color( cl::White);
          $canvas-> bar( $sz[0]-3, 1, $sz[0]-2, $sz[1]-2);
          my $del = int(($sz[0]-6)/16);
          for ( 0..15) {
             $canvas-> color( $_ * 65793 * 16);
             $canvas-> bar( 3 + $_*$del, 1, 2 + ($_+1)*$del, $sz[1] - 2);
          }
          $canvas-> set( 
            fillPattern => fp::WideDot,
            color       => cl::Gray,
            backColor   => cl::Black,
            rop         => rop::XorPut,
          );
          $canvas-> bar( 1, 1, 2 + $a, $sz[1]-2);
          $canvas-> bar( 2 + $b, 1, $sz[0]-2,$sz[1]-2);
          $canvas-> fillPattern( fp::Solid);
          $canvas-> fill_ellipse( $a, $sz[1] / 2, 6, 6);
          $canvas-> fill_ellipse( 4 + $b, $sz[1] / 2, 6, 6);
          $canvas-> color( cl::White);
          $canvas-> text_out( "$a:$b", 1, 1);
       },
       onMouseDown => sub {
          my ( $self, $btn, $mod, $x, $y) = @_;
          my $found;
          $self-> clear_event;
          if ( $x - 3 <= $self-> {min}) { 
              $found = 'min'; 
              $self-> {minLimit}  = 0;
              $self-> {maxLimit}  = $self-> {max} - 1;
          } elsif ( $x - 3 >= $self-> {max}) { 
              $found = 'max';
              $self-> {maxLimit}  = 255;
              $self-> {minLimit}  = $self-> {min} + 1;
          } else {
             return;
          }
          $self-> {transaction} = $found;
          $self-> {last}   = $x;
          $self-> {anchor} = $x - $self-> {$found};
          $self-> capture(1);
       },
       onMouseMove => sub { 
          my ( $self, $mod, $x, $y) = @_; 
          return if !$self-> {transaction};
          $self-> clear_event;
          if ( $x - $self-> {anchor} < $self-> {minLimit}) {
             $x = $self-> {minLimit} + $self-> {anchor};
          } elsif ( $x - $self-> {anchor} > $self-> {maxLimit}) {
             $x = $self-> {maxLimit} + $self-> {anchor};
          }
          return if $self-> {last} == $x;
          $self-> {last} = $x;
          $self-> {$self-> {transaction}} = $x - $self-> {anchor};
          $self-> repaint;
       },
       onMouseUp => sub {
          my ( $self, $btn, $mod, $x, $y) = @_;
          $self-> clear_event;
          return unless $self-> {transaction};
          $self-> {transaction} = 0;
          $self-> capture(0);
       },
   ]);
   $nb-> insert_to_page( 4, [ Label => 
       origin  => [ 20, 170],
       designScale => undef,
       autoWidth => 1,
       text => 'Define spectrum range',
   ], [ Button => 
       origin  => [ 20, 20],
       designScale => undef,
       text => '~Preview',
       hint => 'Turn on auto-stretching before preview',
       name => 'StretchPreview',
       onClick => sub {
          unless ( $w-> {ini}->{autoStretch}) {
             return if Prima::MsgBox::message("Auto stretch feature is not turned on. Turn it on now?", mb::YesNo|mb::Information) != mb::Yes;
             $w-> stretching_state_changed;
          }
          $w-> {ini}-> {SpectrumMin} = $slider-> {min};
          $w-> {ini}-> {SpectrumMax} = $slider-> {max};
          $w-> preprocess;
          $w-> IV-> repaint;
       },
   ]);  
}

sub opt_proppush
{
   my ( $w, $dlg, $nb, $nbpages) = @_;
   $w-> SUPER::opt_proppush( $dlg, $nb, $nbpages);
   $nbpages-> nLines-> value( $w->{ini}->{nLines});
   $nbpages-> ShowExtras-> checked( $w-> {ini}-> {ShowExtras});
   my $ssl = $nbpages-> StretchSlider;
   $ssl-> {saveMin} = $ssl-> {min} = $w->{ini}->{SpectrumMin};
   $ssl-> {saveMax} = $ssl-> {max} = $w->{ini}->{SpectrumMax};
   for ( qw( min max)) { 
      $ssl-> {$_}  = 0   if $ssl-> {$_} < 0;
      $ssl-> {$_}  = 255 if $ssl-> {$_} > 255;
   }
   my $pi = $nbpages-> pageIndex;
   $nbpages-> pageIndex( 4);
   $nbpages-> StretchPreview-> enabled( defined($w-> {file})); 
   $nbpages-> pageIndex( $pi);
}

sub opt_proppop
{
   my ( $w, $dlg, $nb, $nbpages, $mr) = @_;
   $w-> SUPER::opt_proppop( $dlg, $nb, $nbpages, $mr);
   my $ssl = $nbpages-> StretchSlider;
   if ( $mr) {
      $w->{ini}->{nLines} = $nbpages-> nLines-> value;
      $w-> {ini}-> {ShowExtras} = $nbpages-> ShowExtras-> checked;
      my ( $a, $b) = ($ssl-> {min},$ssl-> {max});
      if ( ($w->{ini}->{SpectrumMin} != $a) ||
           ($w->{ini}->{SpectrumMax} != $b)) {
         
         $w->{ini}->{SpectrumMin} = $a;
         $w->{ini}->{SpectrumMax} = $b;
         $w-> preprocess;
      }
      $w-> IV-> repaint;
   } else {
      if ( ($w->{ini}->{SpectrumMin} != $ssl-> {saveMin}) ||
           ($w->{ini}->{SpectrumMax} != $ssl-> {saveMax})) {
         $w->{ini}->{SpectrumMin} = $ssl-> {saveMin};
         $w->{ini}->{SpectrumMax} = $ssl-> {saveMax};
         $w-> preprocess;
         $w-> IV-> repaint;
      }
   }
}

# OPT_END

package Run;


my $wfil = ImageAppWindow::winmenu_file();
splice( @{$$wfil[1]}, -1, 0,
   [ '-FileStats'  => "~Statistics"   => q(show_stats)],
   [ '-FileBackup' => "~Backup results" => q(file_backup)],
   [],
   
);

my $wedt = ImageAppWindow::winmenu_edit();
splice( @{$$wedt[2]}, 0, 0,
   [ EditAutoCrispening => "~Auto crispening" => q(crispen_state_changed) ],
   [ EditAutoStretching => "Auto stretching"  => q(stretching_state_changed) ],
   [],
   [ EditRecSetup => "Recognition ~setup"  => q(win_showrec), ],   
   [ -EditProcess => "~Automatic recognition" => q(process)],
   [ -EditProcessSeries => "Automatic ~series recognition" => q(process_series)],
   [],
);

my $w = LenWindow-> create(
   menuItems => [
      $wfil,
      $wedt,
      ImageAppWindow::winmenu_view(),
      [],["~Help" => [
         [ HelpAbout =>  "~About" => sub {Prima::MsgBox::message("PLab application series, Process Lengths, version 2.00", mb::OK|mb::Information)}],
         [ HelpPlabApps => "~PLab Apps" => sub { $_[0]-> open_help(); }],
         [ HelpContents => "~Contents" => sub { $_[0]-> open_help("PrLens.html"); }],
      ]],
   ],
);
$w-> IV-> delegations(['Paint', 'MouseClick']);
$w-> sb_text("Started OK");
$w-> visible(1);
$w-> select;

$w-> win_extwarn;

run Prima;

!NO!SUBS!

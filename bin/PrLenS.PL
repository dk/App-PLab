package PrLenS;

use strict;
use Prima;
use Prima::Application;
use Prima::StartupWindow;
use PLab::Prima::ImageAppGlyphs;
use IPA::Local;

$::application-> icon( ImageAppGlyphs::icon( bga::processes));

my %fonts;

if ( Prima::Application-> get_system_info()->{gui} == gui::Windows) {
   %fonts = (
      input => { name => "Terminal", size => 12,},
      label => { name => "Arial", size => 10, style => fs::Bold, },
      status => { name => "Terminal", size => 7,},
      info => { name => "Courier", size => 10, style => fs::Bold, },
      info2 => { name => "Arial", size => 10, style => fs::Bold, },
   );
} else {
   %fonts = (
      input => { name => "System VIO", size => 17,},
      label => { name => "Helvetica", size => 10, style => fs::Bold, },
      status => { name => "System VIO", size => 5,},
      info => { name => "Courier", size => 10, style => fs::Bold, },
      info2 => { name => "Helv", size => 10, style => fs::Bold, },
   );
}

use Prima::Widgets;
use Prima::Buttons;
use Prima::Label;
use Prima::InputLine;
use Prima::ScrollBar;
use Prima::StdDlg;
use Prima::IniFile;
use Prima::Utils;
use Prima::MsgBox;
use Prima::Contrib::ButtonGlyphs;
use PLab::Prima::ImageAppGlyphs;
use Cwd;
no Prima::StartupWindow;

my $openDialog;

sub get_main_window
{
   my $w = $_[0];
   $w = $w-> owner while $w-> name ne "MainWindow";
   return $w;
}

sub get_main_panel
{
   return get_main_window($_[0])-> MainPanel;
}

sub reset_possibilities
{
   my $w = get_main_window( $_[0]);
   my $mainPanel= $w-> MainPanel;
   my $tb = $w-> ToolBar;

   $w-> menu-> NextImage-> enabled( defined $mainPanel-> {nextFile});
   $tb-> NextImage-> enabled( defined $mainPanel-> {nextFile});

   $w-> menu-> PrevImage-> enabled( defined $mainPanel-> {prevFile});
   $tb-> PrevImage-> enabled( defined $mainPanel-> {prevFile});

   $w-> menu-> Stats-> enabled( defined $mainPanel-> {file});

   $tb-> MarkCells-> enabled( defined $mainPanel-> {file});
   $tb-> MarkProcesses-> enabled( defined $mainPanel-> {file});
   $tb-> DrawProcesses-> enabled( defined $mainPanel-> {file});
}

sub reset_mark_state
{
   my $w = get_main_window( $_[0]);
   my $mainPanel = $w-> MainPanel;
   my $markState = $w-> ToolBar-> MarkState;

   $mainPanel-> {markState} = $_[1];
   ($markState-> text( "Nothing to mark"), return) unless defined $_[1];
   $markState-> text( "Marking processes") if $_[1] == 0;
   $markState-> text( "Marking cells") if $_[1] == 1;
   $markState-> text( "Drawing processes" . ( $mainPanel->{ binfo}->{ drawMode} ? " (drawing)" : "")) if $_[1] == 2;
}

sub initiate_draw_mode {
   my ( $self, $x, $y) = @_;
   my ( $mp) = get_main_panel( $self);
   return unless ( $mp->{ markState} == 2) && ( ! $mp->{ binfo}->{ drawMode});
   $mp->{ binfo}->{ drawMode} = 1;
   $mp->{ binfo}->{ removeLastPoint} = 1;
   $mp-> capture(1) unless defined( $mp->{ magnify});
   $mp->{ binfo}->{ branchNumber} = scalar @{ $mp->{ branches}};
   $mp->{ branches}->[ $mp->{ binfo}->{ branchNumber}]->[ 0] = [ $x, $y];
   $mp->{ modified} = 1;
   reset_mark_state( $mp, 2);
}

sub calc_branch_length {
   my ( $mp, $br) = @_;
   my ( $xc, $yc) = ( $mp->{ ini}->{ XCalibration}, $mp->{ ini}->{ YCalibration});
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
   my ( $mp, $branches) = ( get_main_panel( $_[0]), $_[ 1]);
   my $totalLength = 0;
   for my $br ( @{$branches}) {
      $totalLength += calc_branch_length( $mp, $br);
   }
   return $totalLength;
}

sub done_draw_mode {
   my ( $mp) = get_main_panel( $_[ 0]);
   return unless defined( $mp->{ markState}) && ( $mp->{ markState} == 2)
                 && $mp->{ binfo}->{ drawMode};
   $mp->{ binfo}->{ drawMode} = 0;
   if ( $mp->{ binfo}->{ removeLastPoint}) {
      splice @{ $mp->{ branches}->[ $mp->{ binfo}->{ branchNumber}]}, -1;
   }
   # removing duplicate sequential point and one point length processes.
   my ( $i, $bn);
   for ( $bn = $#{ $mp->{ branches}}; $bn >= 0; $bn--) {
      for ( $i = $#{ $mp->{ branches}->[ $bn]} - 1; $i >= 0; $i--) {
         if ( ( $mp->{ branches}->[ $bn]->[ $i]->[ 0] == $mp->{ branches}->[ $bn]->[ $i + 1]->[ 0])
              && ( $mp->{ branches}->[ $bn]->[ $i]->[ 1] == $mp->{ branches}->[ $bn]->[ $i + 1]->[ 1])) {
            splice @{ $mp->{ branches}->[ $bn]}, $i, 1;
         }
      }
      if ( scalar( @{ $mp->{ branches}->[ $bn]}) == 1) {
         splice @{ $mp->{ branches}}, $bn, 1;
      }
      else {
         $mp->{ totalLength} += calc_branch_length( $mp, $mp->{ branches}->[ $bn]);
         $mp->{ totalBranches}++;
      }
   }
   $mp-> capture(0) unless defined( $mp->{ magnify});
   reset_mark_state( $mp, 2);
   $mp->repaint;
}

sub preprocess
{
   my $w = get_main_window( $_[0]);
   my $mp = $w-> MainPanel;
   return unless defined $mp-> {file};
   $mp-> {preprocessedImage} = $mp-> {ini}-> {autoCrispen} ? IPA::Local::crispening( $mp-> {im}) : undef;
   if ($mp-> {ini}-> {autoStretch}) {
      my $i = $mp-> {preprocessedImage} || $mp-> {im};
      $mp-> {preprocessedImage} = $i-> dup;
      $mp-> {preprocessedImage}-> resample( $i-> rangeLo, $i-> rangeHi < 50 ? $i-> rangeHi : 50, 0, 255);
#      $mp-> {preprocessedImage}-> resample( $i-> rangeLo, $i-> rangeHi, 0, 255);
   }
}

sub crispen_state_changed
{
   my $w = get_main_window( $_[0]);
   my $mp = $w-> MainPanel;
   $mp-> {ini}-> {autoCrispen} = $w-> menu-> AutoCrispening-> toggle;
   preprocess($w);
   $mp-> repaint;
}

sub stretching_state_changed
{
   my $w = get_main_window( $_[0]);
   my $mp = $w-> MainPanel;
   $mp-> {ini}-> {autoStretch} = $w-> menu-> AutoStretching-> toggle;
   preprocess($w);
   $mp-> repaint;
}

sub set_save_path
{
   my $w = get_main_window( $_[0]);
   my $mp = $w-> MainPanel;
   my $d;

   $d = Prima::Window-> create(
      text       => "Change Save Path",
      size       => [ 480, 200],
      centered   => 1,
      widgetClass  => wc::Dialog,
   );
   $d-> insert( RadioGroup =>
      name => 'default',
      text => '',
      origin => [ 12, 115],
      size => [ 460, 80],);
   $d-> default-> insert( Radio =>
      origin => [ 8, 32],
      width => 440,
      text => 'Use ~default save path',
      checked => $mp-> {ini}-> {defaultSavePath},
      onCheck => sub {
         $d-> SavePath-> enabled(0) if $_[1];
      });
   $d-> default-> insert( Radio =>
      origin => [ 8, 4],
      width => 440,
      text => '~Specify save path',
      checked => ! $mp-> {ini}-> {defaultSavePath},
      onCheck => sub {
         $d-> SavePath-> enabled(1) if $_[1];
      });
   $d-> insert( InputLine =>
      name       => SavePath =>
      text       => $mp-> {ini}-> {SavePath},
      font       => $fonts{ input},
      origin     => [ 12, 80],
      size       => [ 420, 22],
      enabled    => ! $mp-> {ini}-> {defaultSavePath},
   );
   $d-> insert( SpeedButton =>
      name       => Equalize =>
      text       => "<=>",
      origin     => [ 441, 74],
      hint       => "Set save path to current path",
      onClick    => sub {
         $d-> SavePath-> text( $mp-> {ini}-> {path});
      },
   );
   $d-> insert( Button =>
      name       => OK =>
      text       => "~OK",
      origin     => [ 80, 20],
      default    => 1,
      hint       => "Apply changes",
      onClick => sub {
         if ( $d-> default-> index != 0 && ! -d $d-> SavePath-> text) {
            Prima::Utils::beep;
            $d-> SavePath-> focus;
            $d-> SavePath-> selection( 0, 256);
            return;
         }
         $d-> modalResult( cm::Ok);
         $d-> end_modal;
      },
   );
   $d-> insert( Button =>
      name       => Cancel =>
      text       => "~Cancel",
      origin     => [ 290, 20],
      modalResult=> cm::Cancel,
      hint       => "Discard changes",
   );
   $d-> default-> focus;
   ( $mp-> {ini}-> {SavePath} = $d-> SavePath-> text, $mp-> {modified} = 1) if $d-> execute == cm::OK;
   $mp-> {ini}-> {defaultSavePath} = $d-> default-> index == 0 ? 1 : 0;
   $mp-> {ini}-> {defaultSavePath} = 1 unless -d $mp-> {ini}-> {SavePath} && !$mp-> {ini}-> {defaultSavePath};
   $mp-> {ini}-> {SavePath} = &Cwd::abs_path($mp-> {ini}-> {SavePath})
      if -d $mp-> {ini}-> {SavePath};
   $d-> destroy;
}

sub set_test_lines
{
   my $w = get_main_window( $_[0]);
   my $mp = $w-> MainPanel;
   my $d;

   $d = Prima::Window-> create(
      text       => "Change Number of Test Lines",
      size       => [ 480, 120],
      centered   => 1,
      widgetClass => wc::Dialog,
   );
   $d-> insert( InputLine =>
      name       => TestLines =>
      text       => $mp-> {ini}-> {nLines},
      font       => $fonts{input},
      origin     => [ 12, 80],
      size       => [ 460, 22],
   );
   $d-> insert( Button =>
      name       => Cancel =>
      text       => "~Cancel",
      origin     => [ 310, 20],
      modalResult=> cm::Cancel,
      hint       => "Discard changes",
   );
   $d-> insert( Button =>
      name       => Default =>
      text       => "~Default",
      origin     => [ 190, 20],
      default    => 1,
      hint       => "Set default number of lines (6)",
      onClick    => sub
      {
         $d-> TestLines-> text(6);
         $d-> TestLines-> selection( 0, 256);
         $d-> TestLines-> focus;
      }
   );
   $d-> insert( Button =>
      name       => OK =>
      text       => "~OK",
      hint       => "Apply changes",
      origin     => [ 70, 20],
      default    => 1,
      onClick    => sub
      {
         my $txt = $d-> TestLines-> text;
         return unless ($txt =~ /^\d+$/) && ($txt > 0) && ($txt < 20);
         $d-> modalResult( cm::OK);
         $d-> end_modal;
      }
   );
   $d-> TestLines-> selection( 0, 256);
   $d-> TestLines-> focus;
   ( $mp-> {ini}-> {nLines} = $d-> TestLines-> text, $mp-> {modified} = 1) if $d-> execute == cm::OK;
   $d-> destroy;
   $mp-> repaint;
}

sub set_calibrations {
   my ( $self) = @_;
   my ( $mp) = get_main_panel( $self);

   my ( $d) = Prima::Window->create(
                 size      => [ 494, 152],
                 text      => "Set calibrations",
                 widgetClass => wc::Dialog,
                 centered  => 1,
              );
   $d->insert( Label =>
                  name        => XCText =>
                  text        => "X-calibration",
                  font        => $fonts{label},
                  color       => cl::Black,
                  origin      => [ 12, 110],
                  size        => [ 112, 22],
                  valignment  => ta::Bottom,
                  alignment   => ta::Left,
             );
   $d->insert( Label =>
                  name        => YCText =>
                  text        => "Y-calibration",
                  font        => $fonts{label},
                  color       => cl::Black,
                  origin      => [ 12, 80],
                  size        => [ 112, 22],
                  valignment  => ta::Bottom,
                  alignment   => ta::Left,
             );
   my ( $xlWidth) = $d->XCText->get_text_width( $d->XCText->text);
   my ( $ylWidth) = $d->YCText->get_text_width( $d->YCText->text);
   my ( $lWidth) = ( $xlWidth > $ylWidth ? $xlWidth : $ylWidth) + 10;
   $d->XCText->width( $lWidth);
   $d->YCText->width( $lWidth);
   $d->insert( InputLine =>
                  name       => XCalibration =>
                  text       => $mp-> {ini}-> {XCalibration},
                  font       => $fonts{input},
                  origin     => [ 12 + $lWidth, 110],
                  size       => [ $d->width - 24 - $lWidth, 22],
             );
   $d->insert( InputLine =>
                  name       => YCalibration =>
                  text       => $mp-> {ini}-> {YCalibration},
                  font       => $fonts{input},
                  origin     => [ 12 + $lWidth, 80],
                  size       => [ $d->width - 24 - $lWidth, 22],
             );
   $d-> insert( Button =>
                   name       => OK =>
                   text       => "~OK",
                   hint       => "Apply changes",
                   origin     => [ 120, 20],
                   default    => 1,
                   onClick    => sub
                   {
                      my ( $xc, $yc) = ( $d->XCalibration->text, $d->YCalibration->text);
                      $xc =~ s/^\./0\./;
                      $yc =~ s/^\./0\./;
                      return unless ( $xc =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/)
                                    && ( $yc =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/);
                      $mp->{ ini}->{ XCalibration} = $xc;
                      $mp->{ ini}->{ YCalibration} = $yc;
                      $mp->{ modified} = 1;
                      save_info( $mp);
                      load_info( $mp, 1);
                      $mp->{ modified} = 1;
                      $d-> modalResult( cm::OK);
                      $d-> end_modal;
                   }
              );
   $d->insert( Button =>
                  name       => Cancel =>
                  hint       => "Discard changes",
                  text       => "~Cancel",
                  origin     => [ 260, 20],
                  modalResult=> cm::Cancel,
             );

   $d->XCalibration->focus;
   $d->execute;
   $d->destroy;
}

sub update_state
{
   my $w = get_main_window( $_[0]);
   my $mp = $w-> MainPanel;
   my $st = $w-> StatusBar;
   my $cp = $w-> ToolBar-> CellsProcesses;
   if ( !defined $mp-> {file})
   {
      $st-> text( "No file loaded");
      $cp-> text( "???:???");
   }
   else
   {
      $st-> text( "Cells: ". $mp-> {nCells} . "(" . $mp-> {totalCells} . ")" .
                     ",   Processes: ". $mp-> {nProcesses} . "(" . $mp-> {totalProcesses} . ")" .
                     ",   Ratio: " . ($mp-> {totalCells} ? $mp-> {totalProcesses} / $mp-> {totalCells} : "NONE")
      );
      $cp-> text( sprintf( "%03d:%03d", $mp-> {nCells}, $mp-> {nProcesses}));
   }
   show_stats( $_[ 0], undef, 1);
}

sub generate_color_action
{
   my $source = $_[0];
   return sub {
      my ($w,$clr) = @_;
      foreach (qw(Black Blue Green Cyan Red Magenta Brown LightGray LightBlue LightGreen LightCyan LightRed LightMagenta Yellow White))
      {
         my $item = "$source$_";
         my $popup = "${source}ColorChoice";
         $w-> menu-> $item()-> checked($clr eq $item);
         $w-> $popup()-> $item()-> checked($clr eq $item);
      }
      $clr =~ s[^$source][];
      $w-> MainPanel-> {"${source}Color"} = &{$cl::{$clr}}; # <==> eval("cl::$clr");
      $w-> MainPanel-> {ini}-> {"${source}Color"} =
         $w-> MainPanel-> {colors}-> {$w-> MainPanel-> {"${source}Color"}};
      $w-> MainPanel-> repaint;
   };
}

sub generate_color_menu
{
   my $source = $_[0];
   my $action = generate_color_action( $source);
   return (
      [ $source.Black        => "Blac~k"        => $action],
      [ $source.Blue         => "~Blue"         => $action],
      [ $source.Green        => "~Green"        => $action],
      [ $source.Cyan         => "~Cyan"         => $action],
      [ $source.Red          => "~Red"          => $action],
      [ $source.Magenta      => "~Magenta"      => $action],
      [ $source.Brown        => "B~rown"        => $action],
      [ $source.LightGray    => "Gr~ay"         => $action],
      [ $source.LightBlue    => "LightBlue"     => $action],
      [ $source.LightGreen   => "LightGreen"    => $action],
      [ $source.LightCyan    => "LightCyan"     => $action],
      [ $source.LightRed     => "LightRed"      => $action],
      [ $source.LightMagenta => "LightMagenta"  => $action],
      [ $source.Yellow       => "Yellow"        => $action],
      [ $source.White        => "White"         => $action],
   );
}

sub set_color
{
   my ($self, $where, $which) = @_;
   my $colorAction = generate_color_action( $where);
   &$colorAction( $self-> owner, "$where$which");
}

sub main_panel_create
{
   my $self = shift;

   $self-> {modified} = 0;
   $self-> {colors} = {
      cl::Black         => Black          =>
      cl::Blue          => Blue           =>
      cl::Green         => Green          =>
      cl::Cyan          => Cyan           =>
      cl::Red           => Red            =>
      cl::Magenta       => Magenta        =>
      cl::Brown         => Brown          =>
      cl::LightGray     => LightGray      =>
      cl::LightBlue     => LightBlue      =>
      cl::LightGreen    => LightGreen     =>
      cl::LightCyan     => LightCyan      =>
      cl::LightRed      => LightRed       =>
      cl::LightMagenta  => LightMagenta   =>
      cl::Yellow        => Yellow         =>
      cl::White         => White =>};

   reset_mark_state( $self, undef);

   my $uname = lc(Prima::Utils::username() || '');
   $uname .= '.' if $uname;
   $self-> {iniFile} = Prima::IniFile-> create(
      file => "Prima.ini",
      default => [
         "${uname}Process.Length" => [
            path => '.',
            defaultSavePath => 1,
            SavePath => '.',
            WindowRect => '10 70 600 600',
            StatisticsWindowRect => '20 20 600 400',
            autoCrispen => 0,
            autoStretch => 0,
            nLines => 6,
            FrameColor => 'LightMagenta',
            ProcessesColor => 'Blue',
            BranchesColor => 'LightGreen',
            ActiveProcessColor => 'LightGreen',
            CellsColor => 'LightRed',
            XCalibration => 1.25,
            YCalibration => 0.9375,
         ],
      ]);
   $self-> {uname} = $uname;
   $self-> {ini} = $self-> {iniFile}-> section( "${uname}Process.Length");
   $self-> owner-> menu-> AutoCrispening-> checked( $self-> {ini}-> {autoCrispen});
   $self-> owner-> menu-> AutoStretching-> checked( $self-> {ini}-> {autoStretch});
   preprocess( $self);
   set_color( $self, 'Frame', $self-> {ini}-> {FrameColor});
   set_color( $self, 'Processes', $self-> {ini}-> {ProcessesColor});
   set_color( $self, 'Branches', $self-> {ini}-> {BranchesColor});
   set_color( $self, 'Cells', $self-> {ini}-> {CellsColor});
   set_color( $self, 'ActiveProcess', $self-> {ini}-> {ActiveProcessColor});
   $self-> owner-> rect(split ' ', $self-> {ini}-> {WindowRect});
   -d $self-> {ini}-> {path} or $self-> {ini}-> {path} = '.';
   $self-> {ini}-> {path} = &Cwd::abs_path($self-> {ini}-> {path});

   $self-> {ini}-> {defaultSavePath} = 1 unless -d $self-> {ini}-> {SavePath};
   $self-> {ini}-> {SavePath} = &Cwd::abs_path($self-> {ini}-> {SavePath})
      if -d $self-> {ini}-> {SavePath};
   $self-> {file} = undef;
   reset_possibilities( $self);
   update_state( $self);
}

sub main_panel_close
{
   my $self = $_[0];
   $self-> {ini}-> {WindowRect} = "@{[get_main_window($self)-> rect]}";
# ini file rewrite is here
   &save_info( $self);
}

sub main_panel_paint
{
   my $self = $_[0];
   my ($im, $x, $y) =
      ((defined($self-> {preprocessedImage}) ? $self-> {preprocessedImage} : $self-> {im}),
       $self-> size);
   $self-> color( cl::Back);
   if ( $im && $self-> {ini})
   {
      my ($w, $h) = $im-> size;
      $self-> bar ( $w - 1, 0, $x, $y) if $x > $w;
      $self-> bar ( 0, $h - 1, $w, $y) if $y > $h;
      $self-> put_image_indirect(
         $im, 0, 0, $self-> deltaX,
         $im-> height - $self-> height - $self-> deltaY >= 0 ?
         $im-> height - $self-> height - $self-> deltaY : 0,
         $w, $h, $w, $h, rop::CopyPut
      );
      my $dx = sprintf( '%d', $im-> width / 20);
      my $dy = sprintf( '%d', $im-> height / 20);
      my $szy = sprintf( '%d', ($im-> height - 2 * $dy)/$self-> {ini}-> {nLines});
      my $deltaX = -$self-> deltaX;
      my $deltaY = $im-> height - $self-> height - $self-> deltaY >= 0 ? $im-> height - $self-> height - $self-> deltaY : 0;
      $deltaY = -$deltaY;
      $self-> set( lineWidth => 2, color => $self-> {FrameColor});
      $self-> line( $dx + $deltaX, $dy + $deltaY,
                    $deltaX + $im-> width - $dx, $deltaY + $dy);
      $self-> line( $deltaX + $im-> width - $dx, $deltaY + $dy,
                    $deltaX + $im-> width - $dx, $deltaY);
      $self-> line( $dx + $deltaX, $dy + $deltaY,
                    $dx + $deltaX, $deltaY + $im-> height);
      $self-> linePattern( lp::LongDash);
      $self-> line( $dx + $deltaX, $deltaY + $im-> height - $dy,
                    $deltaX + $im-> width - $dx, $deltaY + $im-> height - $dy);
      $self-> line( $deltaX + $im-> width - $dx, $deltaY + $im-> height - $dy,
                    $deltaX + $im-> width - $dx, $deltaY + $dy);
      $self-> set( lineWidth => 1, linePattern => lp::Solid);
      for ( my $i = 1; $i < $self-> {ini}-> {nLines}; $i++)
      {
         $self-> line( $dx + $deltaX, $dy + $deltaY + $szy*$i,
                       $deltaX + $im-> width - $dx, $deltaY + $dy + $szy*$i);
      }

      $self-> color( $self-> {CellsColor});
      foreach (@{$self-> {cells}})
      {
         my ($x, $y) = split;
         $self-> fill_ellipse( $deltaX + $x, $deltaY + $y, 4, 4);
      }

      $self-> color( $self-> {ProcessesColor});
      foreach (@{$self-> {processes}})
      {
         my ($x, $y) = split;
         $self-> fill_ellipse( $deltaX + $x, $deltaY + $y, 4, 4);
      }

      my $lw = $self->lineWidth;
      $self->lineWidth( 1);
      my ( $i) = 0;
      foreach ( @{ $self->{ branches}}) {
         if ( defined( $self->{ binfo}->{ nearestBranch}) && ( $i == $self->{ binfo}->{ nearestBranch})) {
            $self->color( $self->{ ActiveProcessColor});
         }
         else {
            $self->color( $self->{ BranchesColor});
         }
         my ( @br) = map { ( $_->[ 0], $_->[ 1])} @$_;
         $self->polyline( \@br);
         $i++;
      }
      $self->lineWidth( $lw);

   } else { $self-> bar(0, 0, $x, $y); }
}

sub mouse_click
{
   $_[0]-> clear_event;
   my ($mp,$btn,$shift,$x,$y,$dbl) = @_;
   $mp = get_main_panel( $mp);
   return unless defined $mp-> {file};
   if ( $btn == mb::Right)
   {
      if ( ! defined( $mp-> { markState}) || $mp-> { markState} < 2)
      {
         if ( $mp-> {markState})
         {
            reset_mark_state( $mp, 0);
         }
         else
         {
            reset_mark_state( $mp, 1);
         }
      }
      else {
         if ( $mp->{ binfo}->{ drawMode}) {
            done_draw_mode( $_[ 0]);
         }
         elsif ( defined( $mp->{ binfo}->{ nearestBranch})) {
            $mp->{ totalLength} -= calc_branch_length( $mp, $mp->{ branches}->[ $mp->{ binfo}->{ nearestBranch}]);
            $mp->{ totalBranches}--;
            splice @{ $mp->{ branches}}, $mp->{ binfo}->{ nearestBranch}, 1;
            $mp->{ binfo}->{ nearestBranch} = undef;
            $mp->{ modified} = 1;
            $mp->repaint;
            $mp->{ magnify}-> repaint if defined $mp->{ magnify};
         }
         show_stats( $_[ 0], undef, 1);
      }
      return;
   }
   return unless defined $mp-> {markState};
   my $im = $mp-> {im};
   my $deltaX = $mp-> deltaX;
   my $deltaY = $im-> height - $mp-> height - $mp-> deltaY >= 0 ? $im-> height - $mp-> height - $mp-> deltaY : 0;
   $x += $deltaX;  $y += $deltaY;
   return if $x < 0 || $x >= $im-> width;
   return if $y < 0 || $y >= $im-> height;
   my $ary = undef;
   $ary = $mp-> {processes} if $mp-> {markState} == 0;
   $ary = $mp-> {cells} if $mp-> {markState} == 1;
   $ary = $mp-> {branches} if $mp->{ markState} == 2;
   return unless defined $ary;

   if ( $mp->{ markState} == 2) {
      if ( $btn == mb::Left) {
         if ( ! $mp->{ binfo}->{ drawMode}) {
            initiate_draw_mode( $mp, $x, $y);
         }

         my ( $bn) = $mp->{ binfo}->{ branchNumber};
         push @{ $mp->{ branches}->[ $bn]}, [ $x, $y];
         $mp->{ binfo}->{ removeLastPoint} = 1;
      }
   }
   else {
      my ($i,$x1,$x2,$y1,$y2);

      # search for an existing point
      for ( $i = 0; $i < scalar @$ary; $i++)
      {
         ($x1,$y1) = split ' ', $$ary[$i];
         ($x2,$y2) = map { $_ + 6; } ($x1,$y1);
         ($x1,$y1) = map { $_ - 6; } ($x1,$y1);
         last if $x >= $x1 && $x <= $x2 && $y >= $y1 && $y <= $y2;
      }

      $mp-> {modified} = 1;
      if ( $i < scalar @$ary)
      {
         # removing existing point
         ($x, $y) = split(' ', splice( @$ary, $i, 1));
         $mp-> {nCells}-- if $mp-> {markState} == 1;
         $mp-> {nProcesses}-- if $mp-> {markState} == 0;
         $mp-> {totalCells}-- if $mp-> {markState} == 1;
         $mp-> {totalProcesses}-- if $mp-> {markState} == 0;
      }
      else
      {
         # adding new point
         push @$ary, "$x $y";
         $mp-> {nCells}++ if $mp-> {markState} == 1;
         $mp-> {nProcesses}++ if $mp-> {markState} == 0;
         $mp-> {totalCells}++ if $mp-> {markState} == 1;
         $mp-> {totalProcesses}++ if $mp-> {markState} == 0;
      }
      ($x1, $x2, $y1, $y2) = map { ($_ - 6, $_ + 6); } ($x,$y);
      $mp-> invalidate_rect( $x1 - $deltaX, $y1 - $deltaY, $x2 - $deltaX, $y2 - $deltaY);
      $mp->{ magnify}-> repaint if defined $mp->{ magnify};
   }
   update_state( $mp);
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

sub mouse_move {
   my ( $self, $shiftState, $x, $y) = @_;
   my ( $mp) = get_main_panel( $self);
   if ( ( defined $mp->{ binfo})
        && ( defined $mp->{ markState})
        && ( $mp->{ markState} == 2)) {
      if ( $mp->{ binfo}->{ drawMode} == 1) {
         my ( $bn) = $mp->{ binfo}->{ branchNumber};
         my ( $ox, $oy) = @{ $mp->{ branches}->[ $bn]->[ -1]};
         my ( $ms) = $self->get_mouse_state;
         if ( ( scalar( @{ $mp->{ branches}->[ $bn]}) == 1) || ( ( $ms & mb::Left) == mb::Left)) {
            push @{ $mp->{ branches}->[ $bn]}, [ $x, $y];
            $mp->{ binfo}->{ removeLastPoint} = 0;
         }
         else {
            @{ $mp->{ branches}->[ $bn]->[ -1]} = ( $x, $y);
            $mp->{ binfo}->{ removeLastPoint} = 1;
         }
         if ( scalar( @{ $mp->{ branches}->[ $bn]}) > 1) {
            my ( $ex, $ey) = @{ $mp->{ branches}->[ $bn]->[ -1]};
            my ( $bx, $by) = @{ $mp->{ branches}->[ $bn]->[ -2]};
            my ( $left, $bottom, $right, $top) = ( $ox, $oy, $ox, $oy);
            $left = $ex if $left > $ex;
            $left = $bx if $left > $bx;
            $bottom = $ey if $bottom > $ey;
            $bottom = $by if $bottom > $by;
            $right = $ex if $right < $ex;
            $right = $bx if $right < $bx;
            $top = $ey if $top < $ey;
            $top = $by if $top < $by;
            $mp->invalidate_rect( $left, $bottom, $right + 1, $top + 1);
         }
      }
      else {
         my ( $mindist, $bn, $i);
         my ( $rr);
         for ( $i = 0; $i <= $#{ $mp->{ branches}}; $i++) {
            my ( $lmd, $j);
            my ( $left, $bottom, $right, $top) = ( @{ $mp->{ branches}->[ $i]->[ 0]}, @{ $mp->{ branches}->[ $i]->[ 0]});
            for ( $j = 0; $j < $#{ $mp->{ branches}->[ $i]}; $j++) {
               my ( $x1, $y1, $x2, $y2) = ( @{ $mp->{ branches}->[ $i]->[ $j]},
                                            @{ $mp->{ branches}->[ $i]->[ $j + 1]});
               my ( $dist) = point_line_distance( $x1, $y1, $x2, $y2, $x, $y);
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
            if ( ( ! defined( $mp->{ binfo}->{ nearestBranch})) || ( $mp->{ binfo}->{ nearestBranch} != $bn)) {
               $mp->{ binfo}->{ nearestBranch} = $bn;
               $mp->invalidate_rect( @{ $mp->{ binfo}->{ prevActiveRect}}) if defined $mp->{ binfo}->{ prevActiveRect};
               $mp->invalidate_rect( @$rr);
               $mp->{ binfo}->{ prevActiveRect} = $rr;
            }
         }
         elsif ( defined $mp->{ binfo}->{ nearestBranch}) {
            undef $mp->{ binfo}->{ nearestBranch};
            $mp->invalidate_rect( @{ $mp->{ binfo}->{ prevActiveRect}}) if defined $mp->{ binfo}->{ prevActiveRect};
            undef $mp->{ binfo}->{ prevActiveRect};
         }
      }
   }
}

sub mouse_down {
   my ( $mp) = get_main_panel( $_[ 0]);
   my $ms = $_[0]-> get_mouse_state;
   my $lr = mb::Left | mb::Right;
   if ( ( ( $ms & mb::Left) == mb::Left)
           && ( defined $mp->{ markState}) && ( $mp->{ markState} == 2)
           && ( ( ! defined $mp->{ binfo}) || ( ! $mp->{ binfo}->{ drawMode}))) {
      initiate_draw_mode( $_[ 0], $_[ 3], $_[ 4]);
   }
}

sub load_info
{
   my ( $mp, $recalculate) = ( $_[ 0], $_[ 1]);
   my $file = $mp-> {file};
   $mp-> {info} = {};
   my $info = $mp-> {info};
   my ($infoFile, $fNum);
   ($infoFile = "$1.pls", $fNum = $2) if $file =~ m{^.*[\\/]([^\\/]*)(\d\d)\.(?:tif|gif|jpg|bmp)$}i;
   return unless defined $infoFile;
   return unless defined $fNum;
   $infoFile = ($mp-> {ini}-> {defaultSavePath} ? $mp-> {ini}-> {path} : $mp-> {ini}-> {SavePath}) . '/' . $infoFile;
   $infoFile =~ s{[\\/][\\/]}{/}g;
   return unless -f $infoFile;
   open INFO, $infoFile or die "Error opening $infoFile";
   my ($totalCells,$totalProcesses,$totalBranches,$totalLength) = (0,0,0,0);
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
                  $mp->{ ini}->{ XCalibration} = $xcalib + 0.;
                  $mp->{ ini}->{ YCalibration} = $ycalib + 0.;
              }
              else {
                  print "Incorrect Calibrations field value.\n";
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
      my ( $isCurrentFrame) = $fn eq $fNum;
      if ( $isCurrentFrame)
      {
         $ccm =~ tr[\_][\ ];
         my @cells = split ',', $ccm;
         print "Bad number of cells" if scalar @cells != $nc;

         $cpm =~ tr[\_][\ ];
         my @processes = split ',', $cpm;
         print "Bad number of processes" if scalar @processes != $np;

         $mp-> {nCells} = scalar @cells;
         $mp-> {nProcesses} = scalar @processes;
         $mp-> {cells} = [@cells];
         $mp-> {processes} = [@processes];
         undef @cells;
         undef @processes;
      }

      if ( $isCurrentFrame || $recalculate) {
         $mp->{ branches} = [] if $isCurrentFrame;
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
               print "Bad branches description format.\n";
            }
            $bnum++;
         }
         $mp->{ branches} = $pb if $isCurrentFrame;
         $abl = sprintf "%.3f", calc_branches_length( $_[ 0], $pb);
         $ccm =~ tr[\ ][\_];
         $cpm =~ tr[\ ][\_];
         $cbm =~ tr[\ ][\_];
         $info->{ $fn} = "$nc $np $fn\:\:$ccm\:\:$cpm\:\:$abl\&$cbm\n";
         undef @branches;
      }
   }
   close INFO;
   $mp-> {totalCells} = $totalCells;
   $mp-> {totalProcesses} = $totalProcesses;
   $mp-> {totalLength} = $totalLength;
   $mp-> {totalBranches} = $totalBranches;
}

sub save_info
{
   my $mp = $_[0];
   return unless $mp-> {modified};
   my $file = $mp-> {file};
   return unless defined $file;
   my $info = $mp-> {info};
   my ($infoFile, $fNum);
   ($infoFile = "$1.pls", $fNum = $2) if $file =~ m{^.*[\\/]([^\\/]*)(\d\d)\.(?:tif|gif|jpg|bmp)$}i;
   return unless defined $infoFile;
   return unless defined $fNum;
   return unless defined $info;
   $infoFile = ($mp-> {ini}-> {defaultSavePath} ? $mp-> {ini}-> {path} : $mp-> {ini}-> {SavePath})
      . '/' . $infoFile;
   $infoFile =~ s{[\\/][\\/]}{/}g;
   if ( defined $mp-> {nCells} && defined $mp-> {nProcesses} &&
        defined $mp-> {cells} && defined $mp-> {processes})
   {
      my $pp = join( ',', @{$mp-> {processes}});
      my $cc = join( ',', @{$mp-> {cells}});
      my $bb = '';
      if ( defined( $mp->{ branches}) && ( scalar( @{ $mp->{ branches}}) > 0)) {
         $bb = sprintf "%.3f&", calc_branches_length( $_[ 0], $mp->{ branches});
         my ( $branch);
         my ( $comma) = '';
         foreach $branch ( @{ $mp->{ branches}}) {
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
      $info-> {$fNum} = scalar @{$mp-> {cells}} . " " . scalar @{$mp-> {processes}} . " " .
                        "${fNum}::" . $cc . "::" . $pp . "::" . $bb . "\n";
   }
   open INFO, ">$infoFile" or (warn("Error creating $infoFile: $!\n"), return);
   (warn("Cannot write to $infoFile\n"), close(INFO), return) unless -w INFO;
   print INFO "# Number of Test Lines used (may be incorrect): ", $mp-> {ini}-> { nLines}, "\n";
   my $stattext = "#\n " . generate_statistics_text( get_main_window( $mp), $mp);
   $stattext =~ s/^/# /gm;
   $stattext .= "# \n";
   print INFO $stattext;
   print INFO "#*Calibrations: $mp->{ ini}->{ XCalibration} $mp->{ ini}->{ YCalibration}\n";
   foreach ( sort { $a <=> $b } keys %$info)
   {
      print INFO $info-> {$_};
   }
   print INFO $mp-> {totalCells} . " " . $mp-> {totalProcesses} . " **::" .
         ($mp-> {totalCells} ? $mp-> {totalProcesses} / $mp-> {totalCells} : "NONE") . "::\n";
   close INFO;
}

sub load_file
{
   my ($w,$file) = @_;
   my $path = $file;
   $path =~ s{[/\\][^/\\]*$}{};
   my $mainPanel = $w-> MainPanel;
   my ($fileNum, $fileBeg, $fileEnd, $ff);
   $mainPanel-> {preprocessedImage} = undef;

   save_info( $mainPanel);
   my $loaded = Prima::Image-> create( name => $file);
   unless ($loaded-> load ( $file)) {
      message_box( $w->name, "Error loading image: " .
        $loaded-> get_status_string, mb::Ok|mb::Error);
      return;
   }
   $mainPanel-> {im} = $loaded;
   $file =~ m{[/\\]([^/\\]*)$};
   $w-> text( "Process Length - [$1]");
   $mainPanel-> limits ( $mainPanel-> {im}-> size);
   $mainPanel-> {ini}-> {path} = $path;
   $mainPanel-> {file} = $file;
   $mainPanel-> {nextFile} = undef;
   $mainPanel-> {prevFile} = undef;
   $mainPanel-> {nCells} = 0;
   $mainPanel-> {nProcesses} = 0;
   $mainPanel-> {totalCells} = 0;
   $mainPanel-> {totalProcesses} = 0;
   $mainPanel-> {processes} = [];
   $mainPanel-> {cells} = [];
   $mainPanel-> {branches} = [];
   $mainPanel-> {modified} = 0;
   load_info( $mainPanel);

   if ( $file =~ /(.*)(\d\d)(\.(?:tif|gif|jpg|bmp))$/i)
   {
      ($fileBeg,$fileNum,$fileEnd) = ($1,$2,$3);
      $mainPanel-> {prevFile} = $ff
         if ( $fileNum > 0) && ( -f ($ff = sprintf("%s%02d%s",$fileBeg,$fileNum-1,$fileEnd)));
      $mainPanel-> {nextFile} = $ff
         if ( $fileNum < 99) && ( -f ($ff = sprintf("%s%02d%s",$fileBeg,$fileNum+1,$fileEnd)));
   }

   preprocess( $mainPanel);
   reset_mark_state( $mainPanel, undef) unless defined $mainPanel-> {file};
   reset_possibilities( $w);
   update_state( $w);
   $mainPanel-> repaint;
}

sub clear_file
{
   my $w = get_main_window( shift);
   my $mp = $w-> MainPanel;

   $mp-> {preprocessedImage} = undef;
   save_info( $mp);
   $mp-> {im} = undef;
   $w-> text( "Process Length");
   $mp-> limits(0,0);
   $mp-> {file} = undef;
   $mp-> {nextFile} = undef;
   $mp-> {prevFile} = undef;
   $mp-> {nCells} = 0;
   $mp-> {nProcesses} = 0;
   $mp-> {totalCells} = 0;
   $mp-> {totalProcesses} = 0;
   $mp-> {processes} = [];
   $mp-> {cells} = [];
   $mp-> {branches} = [];
   $mp-> {modified} = 0;
   reset_mark_state( $mp, undef) unless defined $mp-> {file};
   reset_possibilities( $w);
   update_state( $w);
   $w-> repaint;
}

sub open_file
{
   my $w = get_main_window( shift);
   my $d;
   my $path = $w-> MainPanel-> {ini}-> {path};
   $path = &Cwd::abs_path( $path);

   $openDialog = $openDialog || Prima::OpenDialog-> create(
      owner       => $w,
      text        => "Open image file",
      defaultExt  => "tif",
      directory   => $path,
      taskListed  => 0,
      fileName    => '',
   );
   my $fName = $openDialog-> execute;
   $fName && load_file( $w, $fName);
}

sub next_image
{
   my $w = get_main_window( shift);
   my $mainPanel = $w-> MainPanel;
   return if defined( $mainPanel->{ binfo}) && $mainPanel->{ binfo}->{ drawMode};
   undef $mainPanel->{ binfo}->{ nearestBranch} if defined $mainPanel->{ binfo}->{ nearestBranch};
   load_file( $w, $mainPanel-> {nextFile})
      if defined $mainPanel-> {nextFile};
   show_stats( $w, undef, 1);
}

sub prev_image
{
   my $w = get_main_window( shift);
   my $mainPanel = $w-> MainPanel;
   return if defined( $mainPanel->{ binfo}) && $mainPanel->{ binfo}->{ drawMode};
   undef $mainPanel->{ binfo}->{ nearestBranch} if defined $mainPanel->{ binfo}->{ nearestBranch};
   load_file( $w, $mainPanel-> {prevFile})
      if defined $mainPanel-> {prevFile};
   show_stats( $w, undef, 1);
}

sub draw_processes {
   my ( $self) = @_;
   my ( $mp) = get_main_panel( $self);
   done_draw_mode( $self);
   $mp->{ binfo}->{ drawMode} = 0;
   undef $mp->{ binfo}->{ nearestBranch};
   undef $mp->{ binfo}->{ prevActiveRect};
   reset_mark_state( $mp, ( defined( $mp-> {markState}) && ( $mp-> {markState} == 2) ? undef : 2))
      if defined $mp-> {file};
   reset_mark_state( $mp, undef) unless defined $mp-> {file};
}

sub mark_cells
{
   my $mp = get_main_panel( $_[0]);
   reset_mark_state( $mp, 1) if defined $mp-> {file};
   reset_mark_state( $mp, undef) unless defined $mp-> {file};
}

sub mark_processes
{
   my $mp = get_main_panel( $_[0]);
   reset_mark_state( $mp, 0) if defined $mp-> {file};
   reset_mark_state( $mp, undef) unless defined $mp-> {file};
}

sub magnify
{
   my $mp = get_main_panel( $_[0]);
   return unless ( $mp-> {im} && $mp-> {ini});
   my ($xHalfSize, $yHalfSize) = ( 100, 70);
   my ($x, $y) = ($mp-> pointerPos);
   my $magn = $mp-> insert( Widget =>
      rect          => [ $x - $xHalfSize - 1, $y - $yHalfSize - 1, $x + $xHalfSize + 1, $y + $yHalfSize + 1],
      selectable    => 1,
      syncPaint     => 0,
      onKeyDown => sub
      {
         if ($_[2] == kb::Esc)
         {
            $_[0]-> clear_event;
            $_[0]-> destroy;
         }
      },
      onPaint => sub
      {
         my $mg = $_[0];
         my ($w, $h) = ($mg-> size);
         my $im = ( defined($mp-> {preprocessedImage}) ? $mp-> {preprocessedImage} : $mp-> {im});
         $mg-> color( cl::Black);
         $mg-> rectangle( 0, 0, $w-1, $h-1);
         if ( $im && $mp-> {ini})
         {
            $mg-> put_image_indirect(
               $im, 1, 1,
               $mp-> deltaX + $mg-> left + $xHalfSize / 2,
               ($im-> height - $mp-> height - $mp-> deltaY >= 0 ?
               $im-> height - $mp-> height - $mp-> deltaY : 0)
               + $mg-> bottom + $yHalfSize / 2,
               $w - 2, $h - 2, $xHalfSize, $yHalfSize, rop::CopyPut
            );
            $mg-> color( cl::Back | wc::Window);
            my $deltaX = $mp-> deltaX;
            my $deltaY = $im-> height - $mp-> height - $mp-> deltaY >= 0 ? $im-> height - $mp-> height - $mp-> deltaY : 0;
            my $dx = sprintf( '%d', $im-> width / 20);
            my $dy = sprintf( '%d', $im-> height / 20);
            my $szy = sprintf( '%d', ($im-> height - 2 * $dy)/$mp-> {ini}-> {nLines});

            my $xa = ($w - 3) / $xHalfSize;
            my $xb = -5*$xHalfSize + 2*$deltaX*$w - 6*$deltaX + 2*$mg-> left*$w-6*$mg-> left+$w*$xHalfSize;
            my $ya = ($h - 3) / $yHalfSize;
            my $yb = -5*$yHalfSize + 2*$deltaY*$h - 6*$deltaY + 2*$mg-> bottom*$h-6*$mg-> bottom+$h*$yHalfSize;
            $xb /= -2*$xHalfSize;
            $yb /= -2*$yHalfSize;
            my ($imw, $imh) = ($im-> width, $im-> height);

            $mg-> bar( 1, 1, $xb, $h - 2) if $xb > 1;
            $mg-> bar( 1, 1, $w - 2, $yb) if $yb > 1;
            $mg-> bar( $xa*$imw+$xb, 1, $w - 2, $h - 2) if $xa*$imw+$xb < $w - 1;
            $mg-> bar( 1, $ya*$imh+$yb, $w - 2, $h - 2) if $ya*$imh+$yb < $h - 1;

            # Drawing of a frame
            my ($xx, $yy);

            $mg-> set( lineWidth => 1, color => $mp-> {FrameColor});
            $yy = $dy * $ya + $yb;
            $mg-> line( $dx * $xa + $xb, $yy, $xa * ($imw - $dx) + $xb, $yy)
               if $yy >= 0 && $yy <= $h;
            $xx = ($imw - $dx)*$xa + $xb;
            $mg-> line( $xx, $yy, $xx, $yb)
               if $xx >= 0 && $xx <= $w;
            $xx = $dx*$xa + $xb;
            $mg-> line( $xx, $yy, $xx, $imh*$ya+$yb)
               if $xx >= 0 && $xx <= $w;
            $mg-> linePattern( lp::LongDash);
            $yy = ($imh-$dy)*$ya+$yb;
            $mg-> line( $xx, $yy, ($imw-$dx)*$xa+$xb, $yy)
               if $yy >= 0 && $yy <= $h;
            $xx = ($imw-$dx)*$xa+$xb;
            $mg-> line( $xx, $yy, $xx, $dy * $ya + $yb)
               if $xx >= 0 && $xx <= $w;
            $mg-> set( lineWidth => 1, linePattern => lp::Solid);
            for ( my $i = 1; $i < $mp-> {ini}-> {nLines}; $i++)
            {
               $yy = ($dy + $szy*$i)*$ya + $yb;
               $mg-> line( $dx*$xa+$xb, $yy, $xx, $yy)
                  if $yy >= 0 && $yy <= $h;
            }

            $mg-> color( $mp-> {CellsColor});
            foreach (@{$mp-> {cells}})
            {
               my ($x, $y) = split;
               $x = $x*$xa + $xb;
               $y = $y*$ya + $yb;
               $mg-> fill_ellipse( $x, $y, 4, 4);
            }

            $mg-> color( $mp-> {ProcessesColor});
            foreach (@{$mp-> {processes}})
            {
               my ($x, $y) = split;
               $x = $x*$xa + $xb;
               $y = $y*$ya + $yb;
               $mg-> fill_ellipse( $x, $y, 4, 4);
            }

            my $lw = $mg-> lineWidth; $mg-> lineWidth(1);
            my ( $i) = 0;
            foreach ( @{ $mp->{ branches}}) {
               if ( defined( $mp->{ binfo}->{ nearestBranch}) && ( $i == $mp->{ binfo}->{ nearestBranch})) {
                  $mg->color( $mp->{ ActiveProcessColor});
               }
               else {
                  $mg->color( $mp->{ BranchesColor});
               }
               my ( @br) = map { ( $_->[ 0] * $xa + $xb, $_->[ 1] * $ya + $yb)} @$_;
               $mg->polyline( \@br);
            }
            $mg-> lineWidth($lw);
         }
         else
         {
            $mg-> color( cl::LightGray);
            $mg-> bar( 1, 1, $w-2, $h-2);
         }
      },
      onDestroy => sub {
         $mp-> {magnify} = undef;
         $_[0]-> capture( 0);
         $mp->capture( 1) if $mp->{ binfo}->{ drawMode};
      },
      onCreate => sub {
         my ($w, $h) = ($_[0]-> size);
         $mp->capture( 0) if $mp->{ binfo}->{ drawMode};
         $_[0]-> capture( 1);
      },
      onMouseMove => sub {
         return if $_[2] - $xHalfSize == 0 && $_[3] - $yHalfSize == 0;
         mouse_move( $mp, $_[ 1], $mp-> screen_to_client( $_[0]-> client_to_screen( $_[2], $_[3])));
         my ($w, $h) = ($_[0]-> size);
         my ($mx,$my) = (-($_[2] - $xHalfSize)*2, -($_[3] - $yHalfSize)*2);
         $_[0]-> scroll( $mx, $my, confineRect => [ 1,1,$w-1,$h-1]);
         $mx = $mx < 0 ? -$mx : $mx;
         $my = $my < 0 ? -$my : $my;
         $_[0]-> origin( $_[0]-> left + $_[2] - $xHalfSize, $_[0]-> bottom + $_[3] - $yHalfSize);
         $_[0]-> repaint if $mp-> { binfo}->{ drawMode};
         $_[0]-> update_view;
         $_[0]-> begin_paint;
         $_[0]-> color( cl::Black);
         $_[0]-> rectangle( 0, 0, $w-1, $h-1);
         $_[0]-> end_paint;
      },
      onMove => sub {
         $mp-> update_view;
      },
   );
   $mp-> {magnify} = $magn;
}

sub generate_statistics_text {
   my ( $mainWindow, $mainPanel) = @_;

   my ( $nc, $nb, $sbl) = ( $mainPanel->{ nCells}, scalar( @{ $mainPanel->{ branches}}),
                            calc_branches_length( $mainWindow, $mainPanel->{ branches}));
   my ( $abl) = ( $nb == 0 ? 0 : $sbl / $nb);
   my ( $blr) = ( $nc == 0 ? 0 : $sbl / $nc);

   my ( $tnc, $tnb, $tbl) = ( $mainPanel->{ totalCells}, $mainPanel->{ totalBranches}, $mainPanel->{ totalLength});
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
   my $w = get_main_window( $_[ 0]);
   my $mp = $w->MainPanel;
   my ( $update_window) = $_[ 2];

   return unless defined $mp->{ branches};

   my ( $sd, $norepaint);
   if ( ! ( $sd = eval { $w->Statistics})) {

      return if $update_window;

      my ( @rect) = split ' ', ( $mp->{ ini}->{ StatisticsWindowRect} ?
                                    ( $mp->{ ini}->{ StatisticsWindowRect}) :
                                    '20 20 600 400'
                               );

      $sd = Prima::Window->create(
         name => 'Statistics',
         rect => [ @rect],
         font => {
                  pitch => fp::Fixed,
                 },
         owner => $w,
         onClose => sub {
            $mp->{ ini}->{ StatisticsWindowRect} = join( ' ', $_[ 0]->rect);
         },
      );

      $sd->insert(
         Button =>
         name => "OK",
         hint       => "Close window",
         text => '~Ok',
         origin => [ 10, 10],
         default => 1,
         modalResult => cm::Ok,
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
         text => generate_statistics_text( $w, $mp),
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
      $sd->StatText->text( generate_statistics_text( $w, $mp));
      $sd->repaint;
   }
}

my $w = Prima::Window->create(
   name       => MainWindow =>
   origin     => [ 2000, 2000],
   size       => [ 531, 594],
   text       => "Process Length",
   menuItems => [
      ["~File" => [
         [ FileOpen       => "~Open"   => "C-O"   => kb::NoKey    => \&open_file],
         [ FileClear      => "~Clear"                             => \&clear_file],
         [ '-NextImage'  => "~Next"   => "->"    => kb::NoKey    => \&next_image],
         [ '-PrevImage'  => "~Prev"   => "<-"    => kb::NoKey    => \&prev_image],
         [],
         [ '-Stats'  => "~Statistics"   => "A-S"    => kb::NoKey    => \&show_stats],
         [],
         [                   "E~xit"   => "A-X"   => '@X'         => sub { $_[0]-> close}],
      ]],
      ["~Options" => [
         [ AutoCrispening => "~Auto crispening" => "SpaceBar" => kb::Space => \&crispen_state_changed ],
         [ AutoStretching => "Auto stretching"  => "C-Space" => km::Ctrl|kb::Space => \&stretching_state_changed ],
         [ SavePath => "~Save path" => \&set_save_path ],
         [ TestLines => "~Test lines" => \&set_test_lines ],
         [ Calibrations => "Ca~librations" => \&set_calibrations ],
         ["~Colors" => [
            [ "Frame ~lines"    => "A-L" => kb::NoKey =>  [ generate_color_menu( 'Frame') ]],
            [ "~Process' marks" => "A-P" => kb::NoKey =>  [ generate_color_menu( 'Processes') ]],
            [ "~Drawn process'" => "A-D" => kb::NoKey =>  [ generate_color_menu( 'Branches') ]],
            [ "~Cell's marks"   => "A-C" => kb::NoKey =>  [ generate_color_menu( 'Cells') ]],
            [ "~Active" => "A-D" => kb::NoKey =>  [ generate_color_menu( 'ActiveProcess') ]],
         ]],
      ]],
   ],
);


$w-> insert( Popup => name => "FrameColorChoice",     items => [ generate_color_menu( 'Frame')],);
$w-> insert( Popup => name => "ProcessesColorChoice", items => [ generate_color_menu( 'Processes')],);
$w-> insert( Popup => name => "BranchesColorChoice",  items => [ generate_color_menu( 'Branches')],);
$w-> insert( Popup => name => "CellsColorChoice",     items => [ generate_color_menu( 'Cells')],);
$w-> insert( Popup => name => "ActiveProcessColorChoice",  items => [ generate_color_menu( 'ActiveProcess')],);
$w-> popup-> autoPopup(0);
$w-> insert(
   AccelTable => name => "Accel",
   items => [
      [A    => "A-L"   => '@L'         =>  sub{$_[0]->FrameColorChoice->popup($_[0]->pointerPos)}],
      [B    => "A-P"   => '@P'         =>  sub{$_[0]->ProcessesColorChoice->popup($_[0]->pointerPos)}],
      [L    => "A-D"   => '@D'         =>  sub{$_[0]->BranchesColorChoice->popup($_[0]->pointerPos)}],
      [C    => "A-C"   => '@C'         =>  sub{$_[0]->CellsColorChoice->popup($_[0]->pointerPos)}],
      [D    => "<-"    => kb::Left     =>  \&prev_image],
      [E    => "->"    => kb::Right    =>  \&next_image],
      [F    => "C-O"   => '^O'         =>  \&open_file],
      [G    => "F3"    => 'F3'         =>  \&open_file],
      [H    => "C"     => 'c'          =>  \&mark_cells],
      [I    => "P"     => 'p'          =>  \&mark_processes],
      [J    => "J"     => '@1'         => sub {
         my $im = $_[0]-> MainPanel-> {im};
         return unless defined $im;
         $im-> begin_paint;
         $im-> color( cl::LightRed);
         $im-> font-> set ( size=>24, name => "Courier", style => fs::Bold);
         $im-> text_out( "Hello", 100, 100);
         $im-> end_paint;
         $_[0]-> MainPanel-> repaint;
      }],
      [K    => "D"     => 'd'          =>  \&draw_processes],
      [M    => "A-S"   => '@S'         =>  \&show_stats],
   ]);

my ($x, $y) = $w-> size;

$w-> insert( "Panel",
   text     => "",
   name     => "StatusBar",
   rect     => [0, 0, $w-> width, 22],
   indent   => 2,
   growMode => gm::GrowHiX,
   font     => $fonts{status},
);

$w-> insert("Panel",
   text     => "",
   name     => "ToolBar",
   rect     => [ 2, $y - 40, $x - 2, $y - 4],
   raise    => 1,
   growMode => gm::GrowHiX | gm::GrowLoY,
);

$w-> ToolBar-> insert(
   [ SpeedButton =>
      origin  => [2, 1],
      glyphs  => 2,
      text    => "",
      image   => Prima::Contrib::ButtonGlyphs::icon( bg::fldropen),
      onClick => \&open_file,
      hint    => "Open file",
   ],
   [ SpeedButton =>
      name    => "PrevImage",
      origin  => [42, 1],
      glyphs  => 2,
      text    => "",
      image   => ImageAppGlyphs::icon( bga::prev),
      enabled => 0,
      onClick => \&prev_image,
      hint    => "Load previous image",
   ],
   [ SpeedButton =>
      name    => "NextImage",
      origin  => [78, 1],
      glyphs  => 2,
      text    => "",
      image   => ImageAppGlyphs::icon( bga::next),
      enabled => 0,
      onClick => \&next_image,
      hint    => "Load next image",
   ],
   [ SpeedButton =>
      name    => "MarkCells",
      origin  => [118, 1],
      glyphs  => 1,
      text    => "",
      image   => ImageAppGlyphs::icon( bga::cells),
      enabled => 0,
      onClick => \&mark_cells,
      hint    => "Mark cells mode",
   ],
   [ SpeedButton =>
      name    => "MarkProcesses",
      origin  => [154, 1],
      glyphs  => 1,
      text    => "",
      image   => ImageAppGlyphs::icon( bga::processes),
      enabled => 0,
      onClick => \&mark_processes,
      hint    => "Mark processes mode",
   ],
   [ SpeedButton =>
      name    => "DrawProcesses",
      origin  => [190, 1],
      glyphs  => 1,
      text    => "",
      image   => ImageAppGlyphs::icon( bga::drawprocesses),
      enabled => 0,
      onClick => \&draw_processes,
      hint    => "Draw processes mode",
   ],
   [ Label =>
      name => "CellsProcesses",
      font => $fonts{info},
      color => cl::Red,
      origin => [ 226, 8],
      text   => "???:???",
   ],
   [ Label =>
      name => "MarkState",
      autoWidth => 1,
      font => $fonts{info2},
      color => cl::Black,
      origin => [ 336, 8],
   ],
);

$w-> insert( Scroller =>
   name                 => "MainPanel",
   rect                 => [ 2, $w-> StatusBar-> height + 2, $x - 2, $y - $w-> ToolBar-> height - 8],
   standardScrollBars   => 1,
   onCreate             => \&main_panel_create,
   onPaint              => \&main_panel_paint,
   onClose              => \&main_panel_close,
   onMouseClick         => sub { mouse_click(@_) },
   onMouseMove          => \&mouse_move,
   onMouseDown          => sub {
      my ( $mp) = get_main_panel( $_[ 0]);
      my $ms = $_[0]-> get_mouse_state;
      my $lr = mb::Left | mb::Right;
      $_[0]-> clear_event;
      if ((($ms&$lr)==$lr)||(($ms&mb::Middle)==mb::Middle))
      {
         if ( defined $_[0]-> {"magnify"})
         {
            $_[0]-> {"magnify"}-> destroy;
         }
         else
         {
            magnify( $_[0]);
         }
      }
      else {
         mouse_down( @_);
      }
   },
   onDestroy            => sub { $::application-> destroy; },
);

run Prima;

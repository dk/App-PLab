package ImageAppWindow::Calibrations;
use vars qw(@ISA);
@ISA = qw(ImageAppWindow);


sub win_inidefaults
{
   my $w = $_[0];
   my @rc = $w-> rect;
   return (
      $w-> SUPER::win_inidefaults,
      XCalibration => 1.25,
      YCalibration => 0.9375,
   );
}


sub opt_propcreate
{
   my ( $w, $dlg, $nb, $nbpages) = @_;
   my @nbpages = @{$nb-> tabs};
   $nb-> set(
      tabs      => [ @nbpages, 'Calibrations'],
      pageCount => scalar(@nbpages) + 1,
   );
   my $pg = $nb-> pageCount;

   $w-> SUPER::opt_propcreate( $dlg, $nb, $nbpages);
# Calibrations
   my %spinPrf = (
      size     => [ 265, 20],
      min      => 0.0001,
      max      => 10,
      step     => 0.01,
   );
   $nb-> insert_to_page( $pg, [
      SpinEdit =>
      origin   => [ 5, 65],
      name     => 'XC',
      %spinPrf,
   ], [
      SpinEdit =>
      origin => [ 5, 10],
      name => 'YC',
      %spinPrf,
   ]);
   $nb-> insert_to_page( $pg, [
      Label     =>
      origin    => [ 5, 90],
      size      => [ 265, 20],
      autoWidth => 0,
      text      => '~X-calibration',
      focusLink => $nbpages-> XC,
   ], [
      Label     =>
      origin    => [ 5, 35],
      size      => [ 265, 20],
      autoWidth => 0,
      text      => '~Y-calibration',
      focusLink => $nbpages-> YC,
   ]);
}

sub opt_proppush
{
   my ( $w, $dlg, $nb, $nbpages) = @_;
   $w-> SUPER::opt_proppush( $dlg, $nb, $nbpages);
# Calibrations
   $nbpages-> XC-> value($w->{ini}->{XCalibration});
   $nbpages-> YC-> value($w->{ini}->{YCalibration});
}

sub opt_proppop
{
   my ( $w, $dlg, $nb, $nbpages, $mr) = @_;
   $w-> SUPER::opt_proppop( $dlg, $nb, $nbpages, $mr);
# Calibrations
   if ( $mr) {
      my ( $xc, $yc) = ( $nbpages-> XC->value, $nbpages-> YC->value);
      $w-> modified( 1) if
         $w->{ini}->{XCalibration} != $xc ||
         $w->{ini}->{YCalibration} != $yc;
      $w->{ini}->{XCalibration} = $xc;
      $w->{ini}->{YCalibration} = $yc;
   }
}

1;


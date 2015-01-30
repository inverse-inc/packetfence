package zicache::timeme;

our $VERBOSE = 0;

sub timeme {
  my ($desc, $fct) = @_;
  my $start = Time::HiRes::gettimeofday();
  $fct->();
  my $end = Time::HiRes::gettimeofday();
  if($VERBOSE) {
    print "$desc took : ";
    printf("%.4f\n", $end - $start);
  }
  return $end - $start;
}

1;

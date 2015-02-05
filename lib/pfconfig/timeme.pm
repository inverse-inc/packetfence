package pfconfig::timeme;

use strict;
use warnings;
use pf::log;

our $VERBOSE = 0;

sub timeme {
  my ($desc, $fct) = @_;
  my $logger = get_logger;
  my $start = Time::HiRes::gettimeofday();
  $fct->();
  my $end = Time::HiRes::gettimeofday();
  if($VERBOSE) {
    my $time = sprintf("%.4f\n", $end - $start);
    $logger->trace("$desc took : $time");
  }
  return $end - $start;
}

1;

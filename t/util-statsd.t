use strict;
use warnings;

use Test::More tests => 3;
use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok('pf::util::statsd') or die;
use pf::util::statsd qw(called);

sub mysub { called(); }

is( mysub(), "main::mysub", "pf::util::statsd::called returns the name of the enclosing subroutine." );

package temp::testing;
use pf::util::statsd "called";
sub mysub { called(); }
Test::More::is( mysub(), "temp::testing::mysub",
    "pf::util::statsd::called returns the name of the enclosing subroutine inside a package." );

use strict;
use warnings;

use Test::More tests => 3;
use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok('pf::StatsD::util') or die;
use pf::StatsD::util "called";

sub mysub { called(); }

is( mysub(), "main::mysub", "pf::StatsD::util::called returns the name of the enclosing subroutine." );

package temp::testing;
use pf::StatsD::util "called";
sub mysub { called(); }
Test::More::is( mysub(), "temp::testing::mysub",
    "pf::StatsD::util::called returns the name of the enclosing subroutine inside a package." );

use strict;
use warnings;

use pfappserver;

my $app = pfappserver->apply_default_middlewares(pfappserver->psgi_app);
$app;

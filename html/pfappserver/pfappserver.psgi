use strict;
use warnings;
use utf8;

use pfappserver;

my $app = pfappserver->apply_default_middlewares(pfappserver->psgi_app);
$app;

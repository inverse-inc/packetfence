use strict;
use warnings;

use configurator;

my $app = configurator->apply_default_middlewares(configurator->psgi_app);
$app;

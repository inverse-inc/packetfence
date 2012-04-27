use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'configurator' }
BEGIN { use_ok 'configurator::Controller::Config' }

ok( request('/config')->is_success, 'Request should succeed' );
done_testing();

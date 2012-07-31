use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'pfappserver' }
BEGIN { use_ok 'pfappserver::Controller::Config' }

ok( request('/config')->is_success, 'Request should succeed' );
done_testing();

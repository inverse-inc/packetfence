use strict;
use warnings;
use Test::More;


use Catalyst::Test 'pfws';
use configurator::Controller::Config::Interface;

ok( request('/interface')->is_success, 'Request should succeed' );
done_testing();

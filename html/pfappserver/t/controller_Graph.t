use strict;
use warnings;
use Test::More;


use Catalyst::Test 'pfappserver';
use pfappserver::Controller::Graph;

ok( request('/graph')->is_success, 'Request should succeed' );
done_testing();

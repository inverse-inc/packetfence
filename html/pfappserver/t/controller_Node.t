use strict;
use warnings;
use Test::More;


use Catalyst::Test 'pfappserver';
use pfappserver::Controller::Node;

ok( request('/node')->is_success, 'Request should succeed' );
done_testing();

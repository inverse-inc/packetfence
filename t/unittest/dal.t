=head1 NAME

dal

=cut

=head1 DESCRIPTION

unit test for pf::dal

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 32;

use pf::error qw(is_success is_error);
use pf::db;
use pf::dal::node;

my $dbh  = eval {
    db_connect();
};

BAIL_OUT("Cannot connect to dbh") unless $dbh;


#This test will running last
use Test::NoWarnings;

my $test_mac = "ff:ff:ff:ff:ff:fe";

pf::dal::node->remove_by_id({mac => $test_mac});

my ($status, $node) = pf::dal::node->find({mac => $test_mac});

is ($status , $STATUS::NOT_FOUND, "Node does not exists");

$node = pf::dal::node->new({ mac => $test_mac, pid => "default"});

ok(!$node->__from_table, "New node not the database");

ok($node, "New node not in the database");

is($node->voip, "no", "node->voip is default 'no'");

ok(is_success($node->save), "Saving $test_mac into the database");

ok($node->__from_table, "New node is in the database");

$node = pf::dal::node->find({mac => $test_mac});

ok($node, "Found node in database");

my $old_session = $node->sessionid;
my $new_session = "$$-new";

$node->sessionid($new_session);

($status, my $node_data) = $node->_update_data;
is_deeply($node_data, {sessionid => $new_session}, "Only saving values that changed");

ok(is_success($node->save), "Saving changes into the database");

$node = pf::dal::node->find({mac => $test_mac});

ok($node, "Reloading node from database");

is($node->sessionid, $new_session, "Changes were saved into database");

$node->voip("bob");

ok(is_error($node->save), "Cannot save invalid enum value into the database");

$node->voip("yes");

ok(is_success($node->save), "Save valid data into the database");

$node = pf::dal::node->find({mac => $test_mac});

ok($node, "Reloading node from database");

is($node->voip, "yes", "Changes were saved into database");

$node->status(undef);

ok(is_error($node->save), "Cannot save a null value into the database");

ok(is_success($node->remove), "Remove node in database");

$node = pf::dal::node->find({mac => $test_mac});

is ($node, undef, "Node does not exists");

$node = pf::dal::node->new({ mac => $test_mac });

ok(is_success($node->save), "Saving node after being deleted");

pf::dal::node->remove_by_id({mac => $test_mac});

$node->voip("yes");

ok(is_success($node->save), "Saving node after being deleted from under us");

$node = pf::dal::node->find({mac => $test_mac});

ok($node, "Saving after being deleted");

is($node->voip, "yes", "Voip was saved");

pf::dal::node->remove_by_id({mac => $test_mac});

$node = pf::dal::node->new({ mac => $test_mac});

ok(is_success($node->save), "new node saved with default values");

$node = pf::dal::node->find({mac => $test_mac});

my $node2 = pf::dal::node->find({mac => $test_mac});

$node->computername("zams-computer");

$node2->voip("yes");

ok(is_success($node->save), "Save node with computername = zams-computer");

ok(is_success($node2->save), "Save node2 with voip = yes");

$node = pf::dal::node->find({mac => $test_mac});

is($node->voip, "yes", "Saving different values do not conflict");

is($node->computername, "zams-computer", "Saving different values do not conflict");

pf::dal::node->remove_by_id({mac => $test_mac});

($status, $node) = pf::dal::node->find_or_create({ mac => $test_mac, computername => "zams-computer", voip => "yes" });

is($status, $STATUS::CREATED, "$test_mac was successfully created");

($status, $node) = pf::dal::node->find_or_create({ mac => $test_mac, computername => "zams-computer", voip => "yes" });

is($status, $STATUS::OK, "$test_mac was successfully updated");

my $data = {"computername" => "computer", voip => "no"};

$node->merge($data);

is($node->voip, $data->{voip}, "Test pf::dal->merge voip");

is($node->computername, $data->{computername}, "Test pf::dal->merge computername");

pf::dal::node->remove_by_id({mac => $test_mac});

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

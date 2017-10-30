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

use Test::More tests => 54;

use pf::error qw(is_success is_error);
use pf::db;
use pf::dal::tenant;
use pf::dal::person;
push @pf::dal::_tenant::INSERTABLE_FIELDS, 'id';
use pf::dal::node;
{
    no warnings 'redefine';
    *pf::api::queue::notify = sub {};
}
my $dbh  = eval {
    db_connect();
};

BAIL_OUT("Cannot connect to dbh") unless $dbh;


#This test will running last
use Test::NoWarnings;

my $test_mac = "ff:ff:ff:ff:ff:fe";

is_deeply(
    pf::dal::node->build_primary_keys_where_clause({mac => $test_mac}),
    {
        'node.mac' => $test_mac,
        'node.tenant_id' => 1,
    },
    "build_primary_keys_where_clause returns fully qualified column names for searching",
);

is_deeply(
    {
        pf::dal::node->update_params_for_select(-where => {mac => $test_mac})
    },
    {
        -where => {
            'node.tenant_id' => 1,
            -and => {
                'mac' => $test_mac,
            }
        }
    },
    "update_params_for_update adds tenant_id"
);

is_deeply(
    {
        pf::dal::node->update_params_for_update(-where => {mac => $test_mac})
    },
    {
        -where => {
            'node.tenant_id' => 1,
            -and => {
                'mac' => $test_mac,
            }
        }
    },
    "update_params_for_update adds tenant_id"
);

is_deeply(
    {
        pf::dal::node->update_params_for_insert(-values => {mac => $test_mac})
    },
    {
        -values => {
            'tenant_id' => 1,
            'mac' => $test_mac,
        }
    },
    "update_params_for_insert adds tenant_id"
);

is_deeply(
    {
        pf::dal::node->update_params_for_upsert(
            -values => {mac => $test_mac},
            -on_conflict => { 'mac' => $test_mac }
        )
    },
    {
        -values => {
            'tenant_id' => 1,
            'mac' => $test_mac,
        },
        -on_conflict => {
            'tenant_id' => 1,
            'mac' => $test_mac,
        }
    },
    "update_params_for_upsert adds tenant_id"
);

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

ok(is_success($node->save), "Save with an invalid voip");

is($node->voip, "no", "After saving a node with invalid voip is set to node");

$node->voip("yes");

ok(is_success($node->save), "Save valid data into the database");

$node = pf::dal::node->find({mac => $test_mac});

ok($node, "Reloading node from database");

is($node->voip, "yes", "Changes were saved into database");

my $old_status = $node->status;

$node->status(undef);

ok(is_success($node->save), "Skip a non-nullable field when saving into the database");

$node = pf::dal::node->find({mac => $test_mac});

is($old_status, $node->status, "non-nullable field is not modified");

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

is($node->category, undef, "Undefined role");

is($node->bypass_role, undef, "Undefined bypass_role");

my $data = {"computername" => "computer", voip => "no", category => "gaming", bypass_role => "guest"};

$node->merge($data);

is($node->voip, $data->{voip}, "Test pf::dal->merge voip");

is($node->computername, $data->{computername}, "Test pf::dal->merge computername");

is($node->category, $data->{category}, "Test pf::dal::node->merge category");

$node->save;

$node = pf::dal::node->find({mac => $test_mac});


is($node->category, $data->{category}, "Test saving category");

is($node->bypass_role, $data->{bypass_role}, "Test saving bypass_role");

ok(is_success($node->save), "Saving twice with no update is allowed");

{
    ($status, my $iter) = pf::dal::node->search(
        -where => {
            mac => $test_mac
        }
    );

    $node = $iter->next;

    isa_ok($node, "pf::dal::node");
}

{

    ($status, my $iter) = pf::dal::node->search(
        -where => {
            mac => $test_mac
        },
        -with_class => undef,
    );

    $node = $iter->next;

    is(ref $node, "HASH", "Check if return row is a simple hash");

}

pf::dal::node->remove_by_id({mac => $test_mac});

is_deeply(
    pf::dal::node->build_primary_keys_where_clause({mac => "00:00:00:00:00:00"}),
    {
        'node.mac' => '00:00:00:00:00:00',
        'node.tenant_id' => 1,
    },
    "build_primary_keys_where_clause returns fullly qualified column names for searching",
);

{
    my $node = pf::dal::node->new({mac => $test_mac});
    my $status = $node->create_or_update();
    is($status, $STATUS::CREATED, "Node created");
    $node = pf::dal::node->new({mac => $test_mac, status => 'reg'});
    $status = $node->create_or_update();
    is($status, $STATUS::OK, "Node updated");
}

{
    my $t_id = 10001;
    pf::dal::tenant->remove_by_id({id => $t_id});
    $status = pf::dal::tenant->create({name => "test", id => $t_id});
    ok(is_success($status), "new tenant is created");
    pf::dal->set_tenant($t_id);
    ($status, my $rows) = pf::dal::person->remove_by_id({pid => 'default'});
    $status = pf::dal::person->create({pid => 'default'});
    ok(is_success($status), "new person is created");
    $node = pf::dal::node->new({mac => $test_mac, pid => "default"});
    $status = $node->save;
    ok(is_success($status), "node is created");
    ($status, $node) = pf::dal::node->find({mac => $test_mac});
    is($node->tenant_id, $t_id, "Node saved with current tenant id");
    pf::dal::node->remove_by_id({mac => $test_mac});
    pf::dal::tenant->remove_by_id({id => $t_id});
    pf::dal::person->remove_by_id({pid => 'default'});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

#!/usr/bin/perl

=head1 NAME

node_source

=head1 DESCRIPTION

Unit test for persisting node.source / node.source_type.

These columns record which authentication source registered a device. person.source
cannot serve that purpose: person is 1:N with node -- many devices share a pid,
commonly 'default' -- so it is last-write-wins across a user's devices.

Every assertion re-reads the row. pf::dal silently drops unknown fields (merge()
iterates the known field list, not the caller's hash) and logs-and-skips invalid
ones, so a successful return from node_modify proves nothing about what was
actually written.

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 18;
use Utils;
use pf::dal::node;
use pf::node;
use pf::api::queue;
use pf::error qw(is_success);

#This test will running last
use Test::NoWarnings;

# node_register and the node create hook enqueue jobs onto the pfqueue redis
# (trigger_security_event / node_discovered). This test is about what lands in
# the node row, not the queue, so stub the enqueue to a no-op -- exactly as
# t/unittest/dal.t does -- rather than requiring a live redis on :6380.
{
    no warnings 'redefine';
    *pf::api::queue::notify         = sub { };
    *pf::api::queue::notify_delayed = sub { };
}

# Re-read a node straight from the database.
sub fetch {
    my ($mac) = @_;
    my ( $status, $obj ) = pf::dal::node->find( { mac => $mac } );
    return is_success($status) ? $obj : undef;
}

=head2 the captive portal path

DynamicRouting::Module::Authentication::update_person_from_fields calls
node_modify($mac, source => ..., source_type => ...) alongside person_modify.

=cut

{
    my $mac = Utils::test_mac();
    ok( node_add_simple($mac), "$mac added" );

    ok( node_modify( $mac, source => 'sms1', source_type => 'SMS', source_base_type => 'SMS' ),
        "node_modify returned success" );

    my $node = fetch($mac);
    is( $node->{source},           'sms1', "source persisted by node_modify" );
    is( $node->{source_type},      'SMS',  "source_type persisted by node_modify" );
    is( $node->{source_base_type}, 'SMS',  "source_base_type persisted by node_modify" );
}

=head2 the RADIUS path

pf::radius::authorize assigns onto $args->{node_info}, which *is* the node object,
then calls $node_obj->save. Nothing copies source_type into the %info hash, so this
covers whether the object assignment alone is sufficient.

=cut

{
    my $mac = Utils::test_mac();
    my ( $status, $obj ) = pf::dal::node->find_or_create( { mac => $mac } );
    ok( is_success($status), "$mac created" );

    $obj->{source}           = 'ad1';
    $obj->{source_type}      = 'AD';
    # AD is an LDAPSource subclass, so its family is LDAP -- this is the value
    # that lets a consumer match every directory source without listing them.
    $obj->{source_base_type} = 'LDAP';
    ok( is_success( $obj->save ), "save returned success" );

    my $node = fetch($mac);
    is( $node->{source},           'ad1',  "source persisted by direct assignment + save" );
    is( $node->{source_type},      'AD',   "source_type persisted by direct assignment + save" );
    is( $node->{source_base_type}, 'LDAP', "source_base_type persisted by direct assignment + save" );
}

=head2 node_register

pf::node::node_register deletes source from %info after handing it to person_modify
and before passing %info to node_modify, so the value never reaches the node.
source_type is not deleted, which risks a half-written row.

=cut

{
    my $mac = Utils::test_mac();
    ok( node_add_simple($mac), "$mac added" );

    # A category is mandatory: is_max_reg_nodes_reached() falls back to "maximum
    # reached" when no role is supplied, and node_register bails before the node
    # write. 'default' has max_nodes_per_pid = 0 (unlimited).
    my ($ok) = node_register( $mac, 'someuser@example.com',
        category => 'default', source => 'sponsor1', source_type => 'SponsorEmail',
        source_base_type => 'SponsorEmail' );
    ok( $ok, "node_register succeeded" );

    my $node = fetch($mac);
    is( $node->{source},           'sponsor1',     "source survives node_register" );
    is( $node->{source_type},      'SponsorEmail', "source_type survives node_register" );
    is( $node->{source_base_type}, 'SponsorEmail', "source_base_type survives node_register" );
}

=head2 source_type is NOT NULL

Passing undef for a NOT NULL column is logged and skipped by validate_field, not
written, and the save still reports success -- so the previous value must remain.

=cut

{
    my $mac = Utils::test_mac();
    ok( node_add_simple($mac), "$mac added" );
    node_modify( $mac, source => 'email1', source_type => 'Email' );
    node_modify( $mac, source_type => undef );

    my $node = fetch($mac);
    is( $node->{source_type}, 'Email', "undef source_type is skipped, prior value kept" );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA.

=cut

1;

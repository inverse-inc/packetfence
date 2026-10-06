#!/usr/bin/perl

=head1 NAME

node_source

=head1 DESCRIPTION

Unit test for persisting node.source and the type columns derived from it.

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

use Test::More tests => 39;
use Utils;
use pf::dal::node;
use pf::node;
use pf::api::queue;
use pf::radius;
use pf::UnifiedApi::Controller::Nodes;
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

DynamicRouting::Module::Root::apply_new_node_info calls
node_modify($mac, source => ...) once node_register succeeded. Only the id is
passed: pf::dal::node derives source_type and source_base_type from it.

=cut

{
    my $mac = Utils::test_mac();
    ok( node_add_simple($mac), "$mac added" );

    ok( node_modify( $mac, source => 'sms' ), "node_modify returned success" );

    my $node = fetch($mac);
    is( $node->{source},           'sms', "source persisted by node_modify" );
    is( $node->{source_type},      'SMS', "source_type derived from source" );
    is( $node->{source_base_type}, 'SMS', "source_base_type derived from source" );
}

=head2 the RADIUS path

pf::radius::authorize assigns onto $args->{node_info}, which *is* the node object,
then calls $node_obj->save. It sets only source; the save derives the rest.

=cut

{
    my $mac = Utils::test_mac();
    my ( $status, $obj ) = pf::dal::node->find_or_create( { mac => $mac } );
    ok( is_success($status), "$mac created" );

    # 'LDAP' is an AD source. AD is an LDAPSource subclass, so its family is LDAP
    # -- the value that lets a consumer match every directory source without
    # listing them.
    $obj->{source} = 'LDAP';
    ok( is_success( $obj->save ), "save returned success" );

    my $node = fetch($mac);
    is( $node->{source},           'LDAP', "source persisted by direct assignment + save" );
    is( $node->{source_type},      'AD',   "source_type derived on save" );
    is( $node->{source_base_type}, 'LDAP', "source_base_type derived on save" );
}

=head2 node_register keeps the source

Regression test for commit 1e1b8c8. pf::node::node_register used to delete source
from %info (after handing it to person_modify) before passing %info to node_modify,
so the value never reached the node. It now keeps source, and the type columns
are derived from it.

=cut

{
    my $mac = Utils::test_mac();
    ok( node_add_simple($mac), "$mac added" );

    # A category is mandatory: is_max_reg_nodes_reached() falls back to "maximum
    # reached" when no role is supplied, and node_register bails before the node
    # write. 'default' has max_nodes_per_pid = 0 (unlimited).
    my ($ok) = node_register( $mac, 'someuser@example.com',
        category => 'default', source => 'sponsor_uppercase_allowed' );
    ok( $ok, "node_register succeeded" );

    my $node = fetch($mac);
    is( $node->{source},           'sponsor_uppercase_allowed', "source survives node_register" );
    is( $node->{source_type},      'SponsorEmail', "source_type derived through node_register" );
    is( $node->{source_base_type}, 'SponsorEmail', "source_base_type derived through node_register" );
}

=head2 the type columns follow source

Callers such as api.pm dynamic_register_node, RADIUS/pfsnmp autoreg
(getNodeInfoForAutoReg) and import pass source alone. A device registered via one
source and later re-registered via another must not keep the first one's types,
or usage counting puts it in the wrong family.

=cut

{
    my $mac = Utils::test_mac();
    ok( node_add_simple($mac), "$mac added" );

    my ($ok) = node_register( $mac, 'someuser@example.com', category => 'default', source => 'openid' );
    ok( $ok, "registered via openid" );
    my $node = fetch($mac);
    is( $node->{source_type},      'OpenID', "source_type is OpenID" );
    is( $node->{source_base_type}, 'OAuth',  "source_base_type is OAuth" );

    ($ok) = node_register( $mac, 'someuser@example.com', category => 'default', source => 'sms' );
    ok( $ok, "re-registered via sms" );
    $node = fetch($mac);
    is( $node->{source_type},      'SMS', "source_type follows the new source" );
    is( $node->{source_base_type}, 'SMS', "source_base_type follows the new source" );
}

=head2 an unchanged source keeps its recorded types

The types are only derived when source changes, so a later save of the node does
not blank them once the source has been deleted from authentication.conf.

=cut

{
    my $mac = Utils::test_mac();
    ok( node_add_simple($mac), "$mac added" );

    # Write the row as it was recorded while 'deleted_source' still existed. A
    # plain UPDATE, so the derivation in pre_save does not run.
    my ($status) = pf::dal::node->update_items(
        -set   => { source => 'deleted_source', source_type => 'Facebook', source_base_type => 'OAuth' },
        -where => { mac => $mac },
    );
    ok( is_success($status), "recorded a source that no longer exists" );

    ok( node_modify( $mac, notes => 'touched' ), "unrelated node_modify returned success" );

    my $node = fetch($mac);
    is( $node->{source_type},      'Facebook', "source_type kept while source is unchanged" );
    is( $node->{source_base_type}, 'OAuth',    "source_base_type kept while source is unchanged" );
}

=head2 an unknown source is UNCLASSIFIED

=cut

{
    my $mac = Utils::test_mac();
    ok( node_add_simple($mac), "$mac added" );
    node_modify( $mac, source => 'sms' );
    node_modify( $mac, source => 'no_such_source' );

    my $node = fetch($mac);
    is( $node->{source},           'no_such_source', "source persisted" );
    is( $node->{source_type},      '', "source_type is '' (UNCLASSIFIED), not the previous source's" );
    is( $node->{source_base_type}, '', "source_base_type is '' (UNCLASSIFIED), not the previous source's" );
}

=head2 source_type is NOT NULL

Passing undef for a NOT NULL column is logged and skipped by validate_field, not
written, and the save still reports success -- so the previous value must remain.

=cut

{
    my $mac = Utils::test_mac();
    ok( node_add_simple($mac), "$mac added" );
    node_modify( $mac, source => 'email' );
    node_modify( $mac, source_type => undef );

    my $node = fetch($mac);
    is( $node->{source_type}, 'Email', "undef source_type is skipped, prior value kept" );
}

=head2 the Nodes API

PATCH /api/v1/node/:id is a plain SQL UPDATE that bypasses pre_save, so
update_data derives the type columns itself.

=cut

{
    my %data = ( source => 'openid' );
    pf::UnifiedApi::Controller::Nodes->update_source_types( \%data );
    is( $data{source_type},      'OpenID', "API update derives source_type" );
    is( $data{source_base_type}, 'OAuth',  "API update derives source_base_type" );

    my %other = ( notes => 'x' );
    pf::UnifiedApi::Controller::Nodes->update_source_types( \%other );
    ok( !exists $other{source_type}, "API update without source leaves the type columns alone" );
}

=head2 the RADIUS audit log

node_info is the node object, so it carries the source persisted by an earlier
login. PacketFence-Source must only report the source this request matched.

=cut

{
    my $radius = pf::radius->new;
    my $node   = { status => 'reg', source => 'openid' };

    my %audit = $radius->_addRadiusAudit( { node_info => $node } );
    ok( !exists $audit{RADIUS_AUDIT}{'PacketFence-Source'},
        "no PacketFence-Source when this request matched no source" );

    %audit = $radius->_addRadiusAudit( { node_info => $node, matched_source => 'sms' } );
    is( $audit{RADIUS_AUDIT}{'PacketFence-Source'}, 'sms',
        "PacketFence-Source is the source this request matched" );
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

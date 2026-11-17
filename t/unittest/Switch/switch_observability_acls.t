#!/usr/bin/perl

=head1 NAME

switch_observability_acls

=head1 DESCRIPTION

How pf::Switch::recordReplyObservabilityAcls records the ACLs of each device in
switch_observability_acls, from the Access-Accept sent to the switch

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 12;
use Utils;
use pf::Switch;
use pf::Switch::Cisco::Cisco_IOS_15_5;
use pf::dal::switch_observability_acls;

#This test will running last
use Test::NoWarnings;

my %acl_map = (AccessListMap => 'Y');
my $switch_a = pf::Switch::Cisco::Cisco_IOS_15_5->new({ id => "switch-observability-a-$$", %acl_map });
my $switch_b = pf::Switch::Cisco::Cisco_IOS_15_5->new({ id => "switch-observability-b-$$", %acl_map });
my @switch_ids = ($switch_a->{_id}, $switch_b->{_id});
my ($mac1, $mac2) = (Utils::test_mac(), Utils::test_mac());

my $acl = 'ip:inacl#101=permit tcp any any';
my $reply = [ $RADIUS::RLM_MODULE_OK, 'Cisco-AVPair' => [ $acl ] ];

sub record {
    my ($switch, $mac, $port, $reply_array) = @_;
    $switch->recordReplyObservabilityAcls({ mac => $mac, user_role => 'r3', ifIndex => $port }, $reply_array // $reply);
}

sub rows {
    my (%where) = @_;
    my ($status, $iter) = pf::dal::switch_observability_acls->search(
        -where => { switch_id => \@switch_ids, %where },
        -order_by => [qw(switch_id mac)],
        -with_class => undef,
    );
    return [ map { [ @{$_}{qw(switch_id mac port)} ] } @{ $iter->all } ];
}

sub cleanup {
    pf::dal::switch_observability_acls->remove_items(-where => { switch_id => \@switch_ids });
}

cleanup();

record($switch_a, $mac1, '10');
record($switch_a, $mac2, '10');
is_deeply(
    rows(),
    [ sort { $a->[1] cmp $b->[1] } [ $switch_ids[0], $mac1, '10' ], [ $switch_ids[0], $mac2, '10' ] ],
    "Both devices of the port are recorded",
);
my ($status, $iter) = pf::dal::switch_observability_acls->search(-where => { mac => $mac1 }, -with_class => undef);
is($iter->all->[0]{acls}, $acl, "The row holds the ACL of the reply");

record($switch_a, $mac1, '10');
is(scalar @{ rows() }, 2, "Re-authenticating a device keeps the other device of the port");

record($switch_a, $mac1, '12');
is_deeply(rows(mac => $mac1), [ [ $switch_ids[0], $mac1, '12' ] ], "A device that moved to another port has a single row");

record($switch_b, $mac1, '5');
is_deeply(rows(mac => $mac1), [ [ $switch_ids[1], $mac1, '5' ] ], "A device that moved to another switch is only on the new one");
is_deeply(rows(mac => $mac2), [ [ $switch_ids[0], $mac2, '10' ] ], "The other device stays on its switch");

# An Access-Accept that can't carry an access list leaves the device no row
my $no_map = pf::Switch::Cisco::Cisco_IOS_15_5->new({ id => $switch_ids[1] });
record($no_map, $mac1, '5');
is_deeply(rows(mac => $mac1), [], "A reply on a switch without the Access List Map drops the row of the device");

# A reject leaves the rows alone
record($switch_a, $mac2, '10', [ $RADIUS::RLM_MODULE_USERLOCK ]);
is_deeply(rows(mac => $mac2), [ [ $switch_ids[0], $mac2, '10' ] ], "A rejected request leaves the rows of the device");

# The role rows of the Push ACLs (empty MAC) of the other switches are kept
pf::dal::switch_observability_acls->new({
    switch_id => $switch_ids[1],
    mac => '',
    role_id => 'r3',
    acl_type => 'role',
    acls => "permit tcp any any",
})->insert;
record($switch_a, '', undef);
is_deeply(rows(switch_id => $switch_ids[1], mac => ''), [ [ $switch_ids[1], '', undef ] ], "Role rows of other switches are kept without a MAC");
record($switch_a, $mac1, '10');
is_deeply(rows(switch_id => $switch_ids[1], mac => ''), [ [ $switch_ids[1], '', undef ] ], "Recording a device keeps the role rows");

cleanup();
is(scalar @{ rows() }, 0, "Cleaned up");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

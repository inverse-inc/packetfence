#!/usr/bin/perl

=head1 NAME

switch_observability_acls

=head1 DESCRIPTION

How pf::Switch::getAccessListByName records the ACLs of each device in
switch_observability_acls

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 10;
use Utils;
use pf::Switch;
use pf::dal::switch_observability_acls;

#This test will running last
use Test::NoWarnings;

my $switch_a = pf::Switch->new({ id => "switch-observability-a-$$" });
my $switch_b = pf::Switch->new({ id => "switch-observability-b-$$" });
my @switch_ids = ($switch_a->{_id}, $switch_b->{_id});
my ($mac1, $mac2) = (Utils::test_mac(), Utils::test_mac());

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

# r3 has role ACLs in t/data/roles.conf
is($switch_a->getAccessListByName('r3', $mac1, '10'), "permit tcp any any", "ACL of the first device");
is($switch_a->getAccessListByName('r3', $mac2, '10'), "permit tcp any any", "ACL of the second device");

is_deeply(
    rows(),
    [ sort { $a->[1] cmp $b->[1] } [ $switch_ids[0], $mac1, '10' ], [ $switch_ids[0], $mac2, '10' ] ],
    "Both devices of the port are recorded",
);

$switch_a->getAccessListByName('r3', $mac1, '10');
is(scalar @{ rows() }, 2, "Re-authenticating a device keeps the other device of the port");

$switch_a->getAccessListByName('r3', $mac1, '12');
is_deeply(rows(mac => $mac1), [ [ $switch_ids[0], $mac1, '12' ] ], "A device that moved to another port has a single row");

$switch_b->getAccessListByName('r3', $mac1, '5');
is_deeply(rows(mac => $mac1), [ [ $switch_ids[1], $mac1, '5' ] ], "A device that moved to another switch is only on the new one");
is_deeply(rows(mac => $mac2), [ [ $switch_ids[0], $mac2, '10' ] ], "The other device stays on its switch");

# The role rows of the Push ACLs (empty MAC) of the other switches are kept
pf::dal::switch_observability_acls->new({
    switch_id => $switch_ids[1],
    mac => '',
    role_id => 'r3',
    acl_type => 'role',
    acls => "permit tcp any any",
})->insert;
$switch_a->getAccessListByName('r3', '', undef);
is_deeply(rows(switch_id => $switch_ids[1], mac => ''), [ [ $switch_ids[1], '', undef ] ], "Role rows of other switches are kept without a MAC");

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

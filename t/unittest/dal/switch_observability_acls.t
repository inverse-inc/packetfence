#!/usr/bin/perl

=head1 NAME

switch_observability_acls

=head1 DESCRIPTION

unit test for switch_observability_acls

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);

    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 6;
use Utils;
use pf::dal::switch_observability_acls;

#This test will running last
use Test::NoWarnings;

my $switch_id = "switch-observability-acls-test-$$";
my $port = '10';
my @macs = (Utils::test_mac(), Utils::test_mac());

sub save_acl {
    my ($mac, $role_id) = @_;
    return pf::dal::switch_observability_acls->new({
        switch_id => $switch_id,
        mac => $mac,
        port => $port,
        role_id => $role_id,
        acl_type => 'role',
        acls => "permit ip any any",
        enforcement_timestamp => \"NOW()",
    })->upsert();
}

sub acls_on_port {
    my ($status, $iter) = pf::dal::switch_observability_acls->search(
        -where => { switch_id => $switch_id, port => $port },
        -order_by => 'mac',
        -with_class => undef,
    );
    return [ map { [ $_->{mac}, $_->{role_id} ] } @{ $iter->all } ];
}

pf::dal::switch_observability_acls->remove_items(-where => { switch_id => $switch_id });

# Several MAB devices authenticated on the same switch port each keep their row
save_acl($macs[0], 'default');
save_acl($macs[1], 'guest');

is_deeply(
    acls_on_port(),
    [ sort { $a->[0] cmp $b->[0] } [ $macs[0], 'default' ], [ $macs[1], 'guest' ] ],
    "Two devices on the same port are both recorded",
);

# Re-authenticating one device does not touch the other one
save_acl($macs[0], 'default');
is(scalar @{ acls_on_port() }, 2, "Re-authenticating a device keeps the other device of the port");

{
    my ($status, $count) = pf::dal::switch_observability_acls->count(
        -where => { switch_id => $switch_id, mac => $macs[1] },
    );
    is($count, 1, "Second device still recorded");
}

# Same device moving to another role on the same port: one row per (mac, role)
save_acl($macs[1], 'registration');
is(scalar @{ acls_on_port() }, 3, "A new role of a device on the port adds a row");

pf::dal::switch_observability_acls->remove_items(-where => { switch_id => $switch_id });
is(scalar @{ acls_on_port() }, 0, "Cleaned up");

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

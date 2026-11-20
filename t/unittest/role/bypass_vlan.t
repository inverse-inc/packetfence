#!/usr/bin/perl

=head1 NAME

bypass_vlan

=head1 DESCRIPTION

The bypass VLAN returned by an authentication source (the set_bypass_vlan
action of the HTTP source) is applied to the node by the autoregistration
(pf::role::getNodeInfoForAutoReg), and a role returned without an
unregistration date is applied too.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 16;
use Test::NoWarnings;
use pf::role;
use pf::Authentication::constants;
use pf::config qw($WIRED_MAC_AUTH);

{
    package StubProfileBypassVlan;
    sub new { bless {}, shift }
    sub getName { 'default' }
    sub getFilteredAuthenticationSources { return ({ id => 'http_bypass', type => 'Authorization' }) }
    sub getProvisioners { return [] }
    our $AUTOLOAD;
    sub AUTOLOAD { return 0 }
    sub DESTROY { }
}

# Run the MAB autoregistration with the given values matched by the source and
# return the node info
sub node_info_for {
    my ($values) = @_;
    my @person_modified;
    no warnings qw(redefine once);
    local *pf::role::filterVlan = sub { return undef };
    local *pf::authentication::match2 = sub {
        return $values && { source_id => 'http_bypass', values => $values, actions => [], rule_id => 'default' };
    };
    local *pf::person::person_modify = sub { push @person_modified, [@_]; return 1 };
    my (undef, undef, %node_info) = pf::role->new->getNodeInfoForAutoReg({
        mac             => '02:00:00:00:b1:01',
        user_name       => '02000000b101',
        connection_type => $WIRED_MAC_AUTH,
        node_info       => { pid => 'default', category => '' },
        profile         => StubProfileBypassVlan->new,
    });
    return \%node_info;
}

my $node_info = node_info_for({ $Actions::SET_BYPASS_VLAN => '252', $Actions::SET_ROLE => 'default' });
is($node_info->{bypass_vlan}, '252', 'a bypass VLAN ID from the source is set in the node');
is($node_info->{category}, 'default', 'the role from the source is set with the bypass VLAN');

$node_info = node_info_for({ $Actions::SET_BYPASS_VLAN => 'vlan_guest', $Actions::SET_ROLE => 'default' });
is($node_info->{bypass_vlan}, 'vlan_guest', 'a bypass VLAN name from the source is set in the node');

$node_info = node_info_for({ $Actions::SET_BYPASS_VLAN => '', $Actions::SET_ROLE => 'default' });
ok(exists $node_info->{bypass_vlan}, 'an empty bypass VLAN from the source is set in the node');
is($node_info->{bypass_vlan}, '', 'an empty bypass VLAN from the source removes the bypass VLAN of the node');

$node_info = node_info_for({ $Actions::SET_ROLE => 'default' });
ok(!exists $node_info->{bypass_vlan}, 'without a bypass VLAN from the source the bypass VLAN of the node is left as it is');

$node_info = node_info_for({ $Actions::SET_BYPASS_VLAN => '252' });
is($node_info->{bypass_vlan}, '252', 'a bypass VLAN without a role is set in the node');
ok(!exists $node_info->{category}, 'a bypass VLAN without a role sets no role');

$node_info = node_info_for(undef);
ok(!exists $node_info->{bypass_vlan}, 'no bypass VLAN is set when no source matches');
ok(!exists $node_info->{category}, 'no role is set when no source matches');

# A role without an unregistration date (only an HTTP source can return one)
$node_info = node_info_for({ $Actions::SET_ROLE => 'default' });
is($node_info->{category}, 'default', 'a role without an unregistration date is applied');
ok(!exists $node_info->{unregdate}, 'a role without an unregistration date keeps the unregistration date of the node');
ok(!exists $node_info->{source}, 'a role without an unregistration date does not set the source of the node');

$node_info = node_info_for({ $Actions::SET_ROLE => 'default', $Actions::SET_UNREG_DATE => '2030-01-01' });
is($node_info->{category}, 'default', 'a role with an unregistration date is applied');
is($node_info->{unregdate}, '2030-01-01', 'the unregistration date from the source is set in the node');

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

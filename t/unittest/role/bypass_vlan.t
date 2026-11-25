#!/usr/bin/perl

=head1 NAME

bypass_vlan

=head1 DESCRIPTION

The bypass VLAN returned by an authentication source (the set_bypass_vlan
action of the HTTP source) is applied to the node by the autoregistration
(pf::role::getNodeInfoForAutoReg), and a role returned without an
unregistration date is applied when it comes from an HTTP source.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 25;
use Test::NoWarnings;
use pf::role;
use pf::Authentication::constants;
use pf::config qw($WIRED_MAC_AUTH);
use pf::constants::role qw($VOICE_ROLE);

{
    package StubSourceBypassVlan;
    sub type { $_[0]{type} }
}
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
# return the node info. Options: source_type (HTTP by default), filter_role (the
# role of the VLAN filter) and is_phone
my @person_modified;
sub node_info_for {
    my ($values, %options) = @_;
    my $source_type = $options{source_type} // 'HTTP';
    @person_modified = ();
    no warnings qw(redefine once);
    local *pf::role::filterVlan = sub { return $options{filter_role} };
    local *pf::authentication::getAuthenticationSource = sub {
        return $_[0] eq 'http_bypass' ? bless({ type => $source_type }, 'StubSourceBypassVlan') : undef;
    };
    local *pf::authentication::match2 = sub {
        return $values && { source_id => 'http_bypass', values => $values, actions => [], rule_id => 'default' };
    };
    local *pf::person::person_modify = sub { push @person_modified, [@_]; return 1 };
    my (undef, undef, %node_info) = pf::role->new->getNodeInfoForAutoReg({
        mac             => '02:00:00:00:b1:01',
        user_name       => '02000000b101',
        connection_type => $WIRED_MAC_AUTH,
        node_info       => { pid => 'default', category => '' },
        isPhone         => $options{is_phone},
        profile         => StubProfileBypassVlan->new,
    });
    return \%node_info;
}

my $node_info = node_info_for({ $Actions::SET_BYPASS_VLAN => '252', $Actions::SET_ROLE => 'default' });
is($node_info->{bypass_vlan}, '252', 'a bypass VLAN ID from the source is set in the node');
is_deeply([map { $_->[0] } @person_modified], ['02000000b101'], 'the source of the person is set');
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

# A role without an unregistration date
$node_info = node_info_for({ $Actions::SET_ROLE => 'default' });
is($node_info->{category}, 'default', 'a role without an unregistration date from an HTTP source is applied');
ok(!exists $node_info->{unregdate}, 'a role without an unregistration date keeps the unregistration date of the node');
ok(!exists $node_info->{source}, 'a role without an unregistration date does not set the source of the node');

$node_info = node_info_for({ $Actions::SET_ROLE => 'default', $Actions::SET_UNREG_DATE => '2030-01-01' });
is($node_info->{category}, 'default', 'a role with an unregistration date is applied');
is($node_info->{unregdate}, '2030-01-01', 'the unregistration date from the source is set in the node');

$node_info = node_info_for({ $Actions::SET_ROLE_FROM_SOURCE => 'guest' });
is($node_info->{category}, 'guest', 'a role from source without an unregistration date from an HTTP source is applied');

for my $type (qw(Authorization Blackhole SQL)) {
    $node_info = node_info_for({ $Actions::SET_ROLE => 'default' }, source_type => $type);
    ok(!exists $node_info->{category}, "a role without an unregistration date from a $type source is not applied, as before");
}

$node_info = node_info_for({ $Actions::SET_ROLE => 'default', $Actions::SET_UNREG_DATE => '2030-01-01' }, source_type => 'Authorization');
is($node_info->{category}, 'default', 'a role with an unregistration date from another source is applied, as before');

# The role of the VLAN filter
$node_info = node_info_for(undef, filter_role => 'filtered', is_phone => 1);
is($node_info->{category}, $VOICE_ROLE, 'the voice role of a phone is kept when no source matches');

$node_info = node_info_for({ $Actions::SET_ROLE => 'default' }, filter_role => 'filtered', is_phone => 1);
is($node_info->{category}, $VOICE_ROLE, 'the voice role of a phone is kept when the source returns a role without an unregistration date');

$node_info = node_info_for({ $Actions::SET_ROLE => 'default' }, filter_role => 'filtered');
is($node_info->{category}, 'filtered', 'the role of the VLAN filter is kept over the role of the source');

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

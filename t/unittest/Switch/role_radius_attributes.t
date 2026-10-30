#!/usr/bin/perl

=head1 NAME

role_radius_attributes

=head1 DESCRIPTION

The RADIUS attributes of the role (Role by RADIUS attributes) are added to the
Access-Accept of the switches

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 25;
use Test::NoWarnings;
use pf::Switch;
use pf::Switch::Template;
use pf::config::builder::template_switches;
use pf::Switch::Cisco::Cisco_IOS_15_5;
use pf::Switch::CoovaChilli;
use pf::Switch::Xirrus;
use pf::security_event;
use pf::node;
use File::Temp;
use pfconfig::manager;
use pfconfig::namespaces::config::Switch;

# The modules answering for the external portal look for a security event of the endpoint
{
    no warnings 'redefine';
    *pf::security_event::security_event_view_top = sub { undef };
}

my $attributes = <<'EOT';
# VLANs 30 and 40 tagged (RFC 4675: 0x31000000 + VLAN)
Egress-VLANID = 822083614
Egress-VLANID = 822083624

Session-Timeout = 3600
Lab-Unknown-Attribute = 1
permit ip any any
EOT

sub reply {
    my ($class, $switch_args, $args) = @_;
    my $switch = $class->new({
        id => '10.0.0.8',
        RadiusAttributesMap => 'Y',
        VlanMap => 'Y',
        RoleMap => 'N',
        AccessListMap => 'N',
        radius_attributes => { staff => $attributes },
        %{$switch_args // {}},
    });
    my (undef, %reply) = @{ $switch->returnRadiusAccessAccept({ vlan => 20, user_role => 'staff', unfiltered => 'Y', %{$args // {}} }) };
    return \%reply;
}

my $reply = reply('pf::Switch');
is_deeply($reply->{'Egress-VLANID'}, ['822083614', '822083624'], 'a repeated attribute is returned once per line');
is_deeply($reply->{'Session-Timeout'}, ['3600'], 'an attribute of the role is returned');
ok(!exists $reply->{'Lab-Unknown-Attribute'}, 'an attribute that is not in the dictionary is not returned');
is($reply->{'Tunnel-Private-Group-ID'}, 20, 'the VLAN is still returned');

is_deeply(reply('pf::Switch', {}, { user_role => 'guest' })->{'Egress-VLANID'}, undef, 'the attributes of another role are not returned');
is_deeply(reply('pf::Switch', { RadiusAttributesMap => 'N' })->{'Egress-VLANID'}, undef, 'nothing is returned when Role by RADIUS attributes is disabled');

is_deeply(
    reply('pf::Switch', { radius_attributes => { staff => "Tunnel-Private-Group-Id = 30" } })->{'Tunnel-Private-Group-ID'},
    [20, 30],
    'a value is added to an attribute already in the reply, whatever the case of its name'
);

my (undef, $accept_vlan) = pf::config::builder::template_switches::make_radius_attribute_set("Tunnel-Private-Group-Id = \$vlan");
is_deeply(
    reply('pf::Switch::Template', { template => { acceptVlan => $accept_vlan } }),
    { 'Tunnel-Private-Group-Id' => 20, 'Egress-VLANID' => ['822083614', '822083624'], 'Session-Timeout' => ['3600'] },
    'a switch template returns the attributes of the role'
);

$reply = reply('pf::Switch', { radius_attributes => { staff => "Session-Timeout = abc\nSession-Timeout = 60\nTunnel-Type = 0x100000000" } });
is_deeply(
    [ @{$reply}{qw(Session-Timeout Tunnel-Type)} ],
    [ ['60'], $RADIUS::VLAN ],
    'a value that is not valid for the type of the attribute is not returned'
);

$reply = reply('pf::Switch', { radius_attributes => { staff => "Tunnel-Type = VLAN\nFilter-Id = \"staff\"" } });
is_deeply(
    [ @{$reply}{qw(Tunnel-Type Filter-Id)} ],
    [ [$RADIUS::VLAN, 'VLAN'], ['staff'] ],
    'a value named in the dictionary is returned and the double quotes around a value are removed'
);

$reply = reply('pf::Switch', { radius_attributes => { staff => "Auth-Type = Accept\nSession-Timeout = 60" } });
is_deeply(
    [ @{$reply}{qw(Auth-Type Session-Timeout)} ],
    [ undef, ['60'] ],
    'an internal attribute of FreeRADIUS is not returned'
);

{
    # The messages of the logger of the switch
    package FakeLogger;
    our @messages;
    sub new { bless {}, shift }
    sub info { shift; push @messages, @_ }
    sub warn { shift; push @messages, @_ }
}
{
    no warnings 'redefine';
    local *pf::Switch::logger = sub { FakeLogger->new };
    @FakeLogger::messages = ();
    $reply = reply('pf::Switch', { radius_attributes => { staff => "Tunnel-Password = s3cr3t\nSession-Timeout = s3cr3tvalue" } });
    my @leaks = grep { /s3cr3t/ } @FakeLogger::messages;
    is_deeply($reply->{'Tunnel-Password'}, ['s3cr3t'], 'a password is returned');
    is_deeply(\@leaks, [ "(10.0.0.8) Ignoring the RADIUS attribute Session-Timeout = s3cr3tvalue of the role staff: "
        . "'s3cr3tvalue' is not a valid integer for Session-Timeout" ],
        'the value of a password is not in the logs, the other values are');
}

# The RADIUS attributes of a role can be disabled per role (${role}RadiusAttributesEnabled)
is(reply('pf::Switch', { staffRadiusAttributesEnabled => 'disabled' })->{'Session-Timeout'}, undef,
    'nothing is returned when the RADIUS attributes of the role are disabled');
is_deeply(reply('pf::Switch', { staffRadiusAttributesEnabled => 'enabled' })->{'Session-Timeout'}, ['3600'],
    'the attributes are returned when the RADIUS attributes of the role are enabled');

{
    my $file = File::Temp->new(SUFFIX => '.conf');
    print $file <<'CONF';
[default]
[group radius_attributes]
RadiusAttributesMap=Y
guestRadiusAttributes=Session-Timeout = 30
staffRadiusAttributes=Session-Timeout = 60
[10.0.0.9]
group=radius_attributes
guestRadiusAttributesEnabled=disabled
[10.0.0.10]
group=radius_attributes
CONF
    close $file;
    my $namespace = pfconfig::namespaces::config::Switch->new(pfconfig::manager->new);
    $namespace->{file} = $file->filename;
    my $switches = $namespace->build;
    is_deeply($switches->{'10.0.0.9'}{radius_attributes}, { staff => 'Session-Timeout = 60' },
        'pfconfig removes the RADIUS attributes inherited from the group of a role disabled on the switch');
    is_deeply($switches->{'10.0.0.10'}{radius_attributes},
        { guest => 'Session-Timeout = 30', staff => 'Session-Timeout = 60' },
        'pfconfig keeps the RADIUS attributes of the roles that are not disabled');
    is_deeply($switches->{'group radius_attributes'}{radius_attributes},
        { guest => 'Session-Timeout = 30', staff => 'Session-Timeout = 60' },
        'the group keeps its RADIUS attributes');
}

{
    no warnings 'redefine';
    local *pf::Switch::logger = sub { FakeLogger->new };
    @FakeLogger::messages = ();
    reply('pf::Switch', { radius_attributes => { staff => "Tunnel-Password s3cr3t\nSession-Timeout = 60" } });
    is_deeply(
        [ grep { /s3cr3t|format/ } @FakeLogger::messages ],
        [ "(10.0.0.8) Ignoring the RADIUS attribute 1 of the role staff: the format is 'Attribute-Name = value'" ],
        'a line that is not an attribute is not in the logs'
    );
}

my $registered = { status => $pf::node::STATUS_REGISTERED, unregdate => '0000-00-00 00:00:00' };
is_deeply(
    reply('pf::Switch::CoovaChilli', {}, { node_info => $registered, mac => '00:11:22:33:44:55' }),
    { 'Egress-VLANID' => ['822083614', '822083624'], 'Session-Timeout' => ['3600'] },
    'CoovaChilli returns the attributes of the role'
);

is_deeply(
    reply('pf::Switch::Xirrus', { ExternalPortalEnforcement => 'Y' }, { node_info => $registered, mac => '00:11:22:33:44:55' }),
    { 'Egress-VLANID' => ['822083614', '822083624'], 'Session-Timeout' => ['3600'] },
    'a switch answering for the external portal returns the attributes of the role'
);

my $xirrus = reply('pf::Switch::Xirrus', { ExternalPortalEnforcement => 'N' });
is_deeply($xirrus->{'Session-Timeout'}, ['3600'], 'a switch without the external portal returns the attributes of the role');

is(reply('pf::Switch::CoovaChilli', { RadiusAttributesMap => 'N' }, { node_info => $registered })->{'Session-Timeout'}, undef,
    'CoovaChilli returns nothing when Role by RADIUS attributes is disabled');

# A switch module that adds its own values to Cisco-AVPair expects an array
is_deeply(
    reply('pf::Switch::Cisco::Cisco_IOS_15_5', { radius_attributes => { staff => "Cisco-AVPair = subscriber:command=reauthenticate" } })->{'Cisco-AVPair'},
    ['subscriber:command=reauthenticate'],
    'Cisco-AVPair of the role is returned by a Cisco switch'
);

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

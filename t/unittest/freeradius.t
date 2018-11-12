#!/usr/bin/perl

=head1 NAME

freeradius

=head1 DESCRIPTION

unit test for freeradius

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

use Test::More tests => 3;
use pf::freeradius;
use pf::SwitchFactory;

#This test will running last
use Test::NoWarnings;
my $switch_config = {
    '192.168.1.0/24' => {
        'RoleMap'                   => 'N',
        'wsPwd'                     => '',
        'voiceRole'                 => 'voice',
        'inlineTrigger'             => [],
        'normalRole'                => '',
        'mode'                      => 'production',
        'SNMPCommunityRead'         => 'public',
        'VlanMap'                   => 'Y',
        'useCoA'                    => 'Y',
        'SNMPCommunityWrite'        => 'private',
        'cliUser'                   => undef,
        'ExternalPortalEnforcement' => 'N',
        'VoIPCDPDetect'             => 'Y',
        'roles'                     => {
            'voice'  => 'voice',
            'inline' => 'inline'
        },
        'access_lists'      => {},
        'wsTransport'       => 'http',
        'VoIPDHCPDetect'    => 'Y',
        'AccessListMap'     => 'N',
        'macDetectionRole'  => '',
        'description'       => 'Test Range Switch',
        'SNMPVersionTrap'   => '1',
        'registrationRole'  => '',
        'TenantId'          => '1',
        'type'              => 'Cisco::Catalyst_2900XL',
        'VoIPLLDPDetect'    => 'Y',
        'macDetectionVlan'  => '4',
        'cliPwd'            => undef,
        'cliAccess'         => 'N',
        'urls'              => {},
        'VoIPEnabled'       => 0,
        'cliTransport'      => 'Telnet',
        'isolationVlan'     => '3',
        'REJECTVlan'        => '-1',
        'radiusSecret'      => '',
        'SNMPVersion'       => '1',
        'inlineRole'        => 'inline',
        'cliEnablePwd'      => undef,
        'uplink'            => [ '23', '24' ],
        'SNMPCommunityTrap' => 'public',
        'vlans'             => {
            'isolation'    => '3',
            'REJECT'       => '-1',
            'voice'        => '5',
            'inline'       => '6',
            'normal'       => '1',
            'macDetection' => '4',
            'registration' => '2'
        },
        'macSearchesMaxNb'         => '30',
        'normalVlan'               => '1',
        'UrlMap'                   => 'N',
        'wsUser'                   => undef,
        'registrationVlan'         => '2',
        'voiceVlan'                => '5',
        'isolationRole'            => '',
        'macSearchesSleepInterval' => '2',
        'inlineVlan'               => '6'
    },
    '127.0.0.1' => {
        'RoleMap'                   => 'N',
        'wsPwd'                     => '',
        'voiceRole'                 => 'voice',
        'inlineTrigger'             => [],
        'normalRole'                => '',
        'mode'                      => 'production',
        'SNMPCommunityRead'         => 'public',
        'VlanMap'                   => 'Y',
        'useCoA'                    => 'Y',
        'SNMPCommunityWrite'        => 'private',
        'cliUser'                   => undef,
        'ExternalPortalEnforcement' => 'N',
        'VoIPCDPDetect'             => 'Y',
        'roles'                     => {
            'voice'  => 'voice',
            'inline' => 'inline'
        },
        'access_lists'      => {},
        'wsTransport'       => 'http',
        'VoIPDHCPDetect'    => 'Y',
        'AccessListMap'     => 'N',
        'macDetectionRole'  => '',
        'description'       => 'Switches Default Values',
        'SNMPVersionTrap'   => '1',
        'registrationRole'  => '',
        'TenantId'          => '1',
        'type'              => 'PacketFence',
        'VoIPLLDPDetect'    => 'Y',
        'macDetectionVlan'  => '4',
        'cliPwd'            => undef,
        'cliAccess'         => 'N',
        'urls'              => {},
        'VoIPEnabled'       => 0,
        'cliTransport'      => 'Telnet',
        'isolationVlan'     => '3',
        'REJECTVlan'        => '-1',
        'radiusSecret'      => '',
        'SNMPVersion'       => '1',
        'inlineRole'        => 'inline',
        'cliEnablePwd'      => undef,
        'SNMPCommunityTrap' => 'public',
        'uplink'            => [ 'dynamic' ],
        'vlans'             => {
            'isolation'    => '3',
            'REJECT'       => '-1',
            'voice'        => '5',
            'inline'       => '6',
            'normal'       => '1',
            'macDetection' => '4',
            'registration' => '2'
        },
        'macSearchesMaxNb'         => '30',
        'normalVlan'               => '1',
        'UrlMap'                   => 'N',
        'wsUser'                   => undef,
        'registrationVlan'         => '2',
        'voiceVlan'                => '5',
        'isolationRole'            => '',
        'macSearchesSleepInterval' => '2',
        'inlineVlan'               => '6'
    },
    '192.168.0.1' => {
        'RoleMap'                   => 'N',
        'wsPwd'                     => '',
        'voiceRole'                 => 'voice',
        'inlineTrigger'             => [],
        'normalRole'                => '',
        'mode'                      => 'production',
        'SNMPCommunityRead'         => 'public',
        'VlanMap'                   => 'Y',
        'useCoA'                    => 'Y',
        'SNMPCommunityWrite'        => 'private',
        'cliUser'                   => undef,
        'ExternalPortalEnforcement' => 'N',
        'VoIPCDPDetect'             => 'Y',
        'roles'                     => {
            'voice'  => 'voice',
            'inline' => 'inline'
        },
        'access_lists'      => {},
        'wsTransport'       => 'http',
        'VoIPDHCPDetect'    => 'Y',
        'AccessListMap'     => 'N',
        'macDetectionRole'  => '',
        'description'       => 'Test Switch',
        'SNMPVersionTrap'   => '1',
        'registrationRole'  => '',
        'TenantId'          => '1',
        'type'              => 'Cisco::Catalyst_2900XL',
        'VoIPLLDPDetect'    => 'Y',
        'macDetectionVlan'  => '4',
        'cliPwd'            => undef,
        'cliAccess'         => 'N',
        'urls'              => {},
        'VoIPEnabled'       => 0,
        'cliTransport'      => 'Telnet',
        'isolationVlan'     => '3',
        'REJECTVlan'        => '-1',
        'radiusSecret'      => '',
        'SNMPVersion'       => '1',
        'inlineRole'        => 'inline',
        'cliEnablePwd'      => undef,
        'uplink'            => [ '23', '24' ],
        'SNMPCommunityTrap' => 'public',
        'vlans'             => {
            'isolation'    => '3',
            'REJECT'       => '-1',
            'voice'        => '5',
            'inline'       => '6',
            'normal'       => '1',
            'macDetection' => '4',
            'registration' => '2'
        },
        'macSearchesMaxNb'         => '30',
        'normalVlan'               => '1',
        'UrlMap'                   => 'N',
        'wsUser'                   => undef,
        'registrationVlan'         => '2',
        'voiceVlan'                => '5',
        'isolationRole'            => '',
        'macSearchesSleepInterval' => '2',
        'inlineVlan'               => '6'
    },
    'default' => {
        'RoleMap'                   => 'N',
        'inlineTrigger'             => [],
        'voiceRole'                 => 'voice',
        'wsPwd'                     => '',
        'normalRole'                => '',
        'mode'                      => 'production',
        'SNMPCommunityRead'         => 'public',
        'VlanMap'                   => 'Y',
        'useCoA'                    => 'Y',
        'SNMPCommunityWrite'        => 'private',
        'ExternalPortalEnforcement' => 'N',
        'cliUser'                   => undef,
        'VoIPCDPDetect'             => 'Y',
        'roles'                     => {
            'voice'  => 'voice',
            'inline' => 'inline'
        },
        'access_lists'      => {},
        'wsTransport'       => 'http',
        'VoIPDHCPDetect'    => 'Y',
        'macDetectionRole'  => '',
        'AccessListMap'     => 'N',
        'description'       => 'Switches Default Values',
        'SNMPVersionTrap'   => '1',
        'registrationRole'  => '',
        'TenantId'          => '1',
        'type'              => 'Generic',
        'VoIPLLDPDetect'    => 'Y',
        'macDetectionVlan'  => '4',
        'cliPwd'            => undef,
        'cliAccess'         => 'N',
        'urls'              => {},
        'VoIPEnabled'       => 0,
        'cliTransport'      => 'Telnet',
        'isolationVlan'     => '3',
        'REJECTVlan'        => '-1',
        'radiusSecret'      => '',
        'SNMPVersion'       => '1',
        'cliEnablePwd'      => undef,
        'inlineRole'        => 'inline',
        'uplink'            => [ 'dynamic' ],
        'SNMPCommunityTrap' => 'public',
        'macSearchesMaxNb'  => '30',
        'vlans'             => {
            'isolation'    => '3',
            'REJECT'       => '-1',
            'voice'        => '5',
            'inline'       => '6',
            'normal'       => '1',
            'macDetection' => '4',
            'registration' => '2'
        },
        'normalVlan'               => '1',
        'wsUser'                   => undef,
        'UrlMap'                   => 'N',
        'registrationVlan'         => '2',
        'voiceVlan'                => '5',
        'macSearchesSleepInterval' => '2',
        'isolationRole'            => '',
        'inlineVlan'               => '6'
    },
    '192.168.57.102' => {
        'radiusSecret'      => 'ZTk2Y2Q1Nzc4ODJjMDg3ZmYyMzI3ZjA2',
        'mode'              => 'production',
        'type'              => 'PacketFence',
        'SNMPCommunityTrap' => 'public',
        'SNMPVersionTrap'   => '1'
    }
};

pf::freeradius::freeradius_populate_nas_config($switch_config, 10000);
my $validation = pf::freeradius::validation_results(10000);
ok($validation->{config_valid}, "Config is valid");
$validation = pf::freeradius::validation_results(10001);
ok(!$validation->{config_valid}, "Config is not valid");
pf::freeradius::freeradius_populate_nas_config(\%pf::SwitchFactory::SwitchConfig);

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


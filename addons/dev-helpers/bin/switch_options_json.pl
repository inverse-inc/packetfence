#!/usr/bin/perl

=head1 NAME

switch_options_json -

=head1 DESCRIPTION

switch_options_json

Output format:
```json
{
    "generated": "2026-02-19T14:53:36Z",
    "source" : "local:/usr/local/pf/lib/pf/Switch"
    "featureNames": {
        "WirelessDot1x" : "Wireless 802.1x",
        ...
    },
    "categories": ["Wired", ...],
    "tableFeatures": ["SNMP", ...],
    "deviceCount": 170,
    "devices": [
         {
         "category" : "Wired",
         "package" : "pf::Switch::ThreeCom::Switch_4200G",
         "name" : "3COM 4200G",
         "features": [
            "ExternalPortal" : {
               "tested" : false,
               "supported" : false
            },
            "MABFloatingDevices" : {
               "tested" : false,
               "supported" : false
            },
            ...
         ]
    ]
}
```

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use JSON;
use JSON::PP ();
use Pod::Select;
use Pod::Find qw(pod_where);
use pf::SwitchFactory;
use DateTime;
use Tie::IxHash;


#
# Extract and prepare the data
#
pf::SwitchFactory->preloadAllModules();
my @groups = pf::SwitchFactory::form_options();

my %dict_name_infos = ();
my @list_name_infos = ();

for my $g (@groups) {
    for my $switch_info (@{$g->{options}}) {
        my $name   = $switch_info->{value};
        my $module = "pf::Switch::${name}";

        if (not $switch_info->{is_template}) {
            my $file = pod_where({-inc => 1}, $module);
            my $snmp = '';
            open(my $fh, '>', \$snmp);
            podselect({-sections => ['SNMP'], -output => $fh}, $file);
            close($fh);
            $switch_info->{'SNMP'} = 'true' if $snmp ne '';
        }

        my $aSupports     = $switch_info->{supports};
        my %supportsLookup = map { $_ => 1 } @$aSupports;
        my $supports       = join(',', @$aSupports);

        if ($supports =~ /VPN/) {
            $switch_info->{'vpn'} = 'true';
        } elsif ($supports =~ /Wired/ && $supports =~ /Wireless/) {
            $switch_info->{'wired_wireless'} = 'true';
        } elsif ($supports =~ /Wireless/) {
            $switch_info->{'wireless'} = 'true';
        } elsif ($supports =~ /Wired/ || $supports =~ /RadiusDynamicVlanAssignment/ || $supports =~ /Cdp/) {
            $switch_info->{'wired'} = 'true';
        } else {
            print("<!-- SWITCH WITH ISSUE: $name \t$supports -->\n");
        }

        for my $supportedItem (qw(
            WiredMacAuth WiredDot1x WirelessMacAuth WirelessDot1x
            PushACLs ExternalPortal MABFloatingDevices WebFormRegistration
            AccessListBasedEnforcement RadiusVoip FloatingDevice
            Cdp Lldp RoamingAccounting SaveConfig RoleBasedEnforcement
        )) {
            next unless $supportsLookup{$supportedItem};
            if ($switch_info->{is_template}) {
                $switch_info->{$supportedItem} = 'true';
                next;
            }
            my $supports_method = "supports${supportedItem}";
            my $tested_method   = "supports${supportedItem}Tested";
            next unless $module->$supports_method;
            $switch_info->{$supportedItem} = $module->$tested_method ? 'true' : 'not_tested';
        }

        $dict_name_infos{$name} = $switch_info;
        push @list_name_infos, $name;
    }
}

#
# Table feature definitions
#
my @list_of_types = qw(
    SNMP WiredMacAuth WiredDot1x WirelessMacAuth WirelessDot1x
    ExternalPortal PushACLs AccessListBasedEnforcement RoleBasedEnforcement
    RadiusVoip MABFloatingDevices FloatingDevice
);

tie my %list_of_types_trans, 'Tie::IxHash',
    'SNMP'                       => 'SNMP',
    'WiredMacAuth'               => 'Wired MAC Auth',
    'WiredDot1x'                 => 'Wired 802.1x',
    'WirelessMacAuth'            => 'Wireless MAC Auth',
    'WirelessDot1x'              => 'Wireless 802.1x',
    'ExternalPortal'             => 'Web Auth',
    'PushACLs'                   => 'ACL Precreation',
    'AccessListBasedEnforcement' => 'RADIUS Dynamic ACL',
    'RoleBasedEnforcement'       => 'RADIUS Dynamic Role',
    'RadiusVoip'                 => 'RADIUS VOIP',
    'MABFloatingDevices'         => 'MAB Floating Device',
    'FloatingDevice'             => 'Floating Device',
    'WebFormRegistration'        => 'Web Form',
    'Cdp'                        => 'CDP',
    'Lldp'                       => 'LLDP',
    'RoamingAccounting'          => 'Roaming Accounting',
    'SaveConfig'                 => 'Save Config';

my @list_of_wlc = qw(
    Bluesocket Cambium Cisco::WLC Cisco::WiSM
    Aruba::Controller_200 Aruba::Instant_Access Aruba::WirelessController
    Meru Huawei Ubiquiti::Unifi HP::Controller_MSM710
);
my %wlc_lookup = map { $_ => 1 } @list_of_wlc;

#
# Build clean device list — avoids serialising raw $switch_info objects
#
my @devices;

for my $name (sort { $dict_name_infos{$a}{label} cmp $dict_name_infos{$b}{label} } @list_name_infos)
{
    my $info = $dict_name_infos{$name};

    my $category;
    if ($info->{is_template}) {
        $category = 'Template';
    } elsif ($info->{vpn}) {
        $category = 'VPN';
    } elsif ($info->{wired_wireless} && $wlc_lookup{$name}) {
        $category = 'Wireless Controller';
    } elsif ($info->{wireless} && !$info->{wired_wireless}) {
        $category = 'Wireless';
    } else {
        $category = 'Wired';
    }

    my %features;
    for my $feat (@list_of_types) {
        my $val = $info->{$feat} // '';
        tie my %feat_hash, 'Tie::IxHash',
            supported => ($val ne '')     ? JSON::true : JSON::false,
            tested    => ($val eq 'true') ? JSON::true : JSON::false;
        $features{$feat} = \%feat_hash;
    }

    my ($vendor) = split /::/, $name;
    my $is_tpl = ($category eq 'Template') ? JSON::true : JSON::false;

    my %device;
    tie %device, 'Tie::IxHash',
        name       => $info->{label},
        package    => "pf::Switch::$name",
        vendor     => $vendor,
        category   => $category,
        isTemplate => $is_tpl,
        features   => \%features;

    push @devices, \%device;
}

#
# Assemble and print JSON
#
my $generatedAt = DateTime->now->strftime('%Y-%m-%dT%H:%M:%SZ');

# Build ordered featureNames subset matching @list_of_types
tie my %featureNames, 'Tie::IxHash';
for my $feat (@list_of_types) {
    $featureNames{$feat} = $list_of_types_trans{$feat};
}

my %json_data;
tie %json_data, 'Tie::IxHash',
    generated     => $generatedAt,
    source        => 'local:/usr/local/pf/lib/pf/Switch',
    featureNames  => \%featureNames,
    tableFeatures => \@list_of_types,
    categories    => [qw(Wired Wireless), 'Wireless Controller', 'VPN'],
    deviceCount   => scalar(@devices),
    devices       => \@devices;

print JSON::PP->new->utf8->pretty->indent_length(2)->space_before(0)->encode(\%json_data);

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
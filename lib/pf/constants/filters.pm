package pf::constants::filters;

=head1 NAME

pf::constants::filters

=cut

=head1 DESCRIPTION

Constants for filter engines

=cut

use strict;
use warnings;
use base qw(Exporter);
use Readonly;

use pf::ConfigStore::VlanFilters;
use pf::ConfigStore::RadiusFilters;
use pf::ConfigStore::DhcpFilters;
use pf::ConfigStore::ApacheFilters;
use pf::ConfigStore::DNS_Filters;
use pf::ConfigStore::SwitchFilters;

our @EXPORT_OK = qw(%FILTERS_IDENTIFIERS %CONFIGSTORE_MAP %ENGINE_MAP %FILTER_NAMES);

our %FILTERS_IDENTIFIERS = (
    VLAN_FILTERS   => "vlan-filters",
    RADIUS_FILTERS => "radius-filters",
    DHCP_FILTERS   => "dhcp-filters",
    APACHE_FILTERS => "apache-filters",
    DNS_FILTERS    => "dns-filters",
    SWITCH_FILTERS => "switch-filters",
);

our %CONFIGSTORE_MAP = (
    $FILTERS_IDENTIFIERS{VLAN_FILTERS}   => pf::ConfigStore::VlanFilters->new,
    $FILTERS_IDENTIFIERS{RADIUS_FILTERS} => pf::ConfigStore::RadiusFilters->new,
    $FILTERS_IDENTIFIERS{DHCP_FILTERS}   => pf::ConfigStore::DhcpFilters->new,
    $FILTERS_IDENTIFIERS{APACHE_FILTERS} => pf::ConfigStore::ApacheFilters->new,
    $FILTERS_IDENTIFIERS{DNS_FILTERS}    => pf::ConfigStore::DNS_Filters->new,
    $FILTERS_IDENTIFIERS{SWITCH_FILTERS}    => pf::ConfigStore::SwitchFilters->new,
);

our %ENGINE_MAP = (
    $FILTERS_IDENTIFIERS{VLAN_FILTERS}   => "FilterEngine::VlanScopes",
    $FILTERS_IDENTIFIERS{RADIUS_FILTERS} => "FilterEngine::RadiusScopes",
    $FILTERS_IDENTIFIERS{DHCP_FILTERS}   => "FilterEngine::DhcpScopes",
    $FILTERS_IDENTIFIERS{APACHE_FILTERS} => $CONFIGSTORE_MAP{"apache-filters"}->pfconfigNamespace,
    $FILTERS_IDENTIFIERS{DNS_FILTERS}    => "FilterEngine::DNS_Scopes",
    $FILTERS_IDENTIFIERS{SWITCH_FILTERS}    => "FilterEngine::SwitchScopes",
);

our %FILTER_NAMES = (
    vlan   => "VLAN filters",
    radius => "RADIUS filters",
    dhcp   => "DHCP filters",
    apache => "Apache filters",
    dns    => "DNS filters",
    switch => "Switch filters",
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

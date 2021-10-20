#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-11.2-rename-connection_sub_type.pl

=cut

=head1 DESCRIPTION

Rename connection_sub_type in profiles.conf vlan_filters.conf switche_filters.conf and radius_filters.conf

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $profiles_config_file
    $vlan_filters_config_file
    $radius_filters_config_file
    $switch_filters_config_file
);

run_as_pf();

my $profiles = pf::IniFiles->new(-file => $profiles_config_file, -allowempty => 1);

our $sub_connection_type = qr/(Base|VALUE|EAP-3Com-Wireless|MS-EAP-Authentication|EAP-MSCHAP-V2|EAP-Actiontec-Wireless|EAP-HTTP-Digest|EAP-SPEKE|EAP-MOBAC|EAP-Link|EAP-PAX|EAP-PSK|EAP-SAKE|EAP-AKA2|EAP-GPSK|EAP-PWD|EAP-EVEv1|MS-CHAP-V2)/;

our %new_sub_connection_type = (
    "Base" => "None",
    "VALUE" => "None",
    "EAP-3Com-Wireless" => "3Com-Wireless",
    "EAP-MSCHAP-V2" => "Cisco-MS-CHAPv2",
    "MS-EAP-Authentication" => "Microsoft-MS-CHAPv2",
    "EAP-Actiontec-Wireless" => "Actiontec-Wireless",
    "EAP-HTTP-Digest" => "HTTP-Digest",
    "EAP-SPEKE" => "SPEKE",
    "EAP-MOBAC" => "MOBAC",
    "EAP-Link" => "Link",
    "EAP-PAX" => "PAX",
    "EAP-PSK" => "PSK",
    "EAP-SAKE" => "SAKE",
    "EAP-AKA2" => "AKA2",
    "EAP-GPSK" => "GPSK",
    "EAP-PWD" => "PWD",
    "EAP-EVEv1" => "EXEV1",
    "MS-CHAP-V2" => "MSCHAPV2"
);

for my $section ($profiles->Sections()) {
    if (my $filters = $profiles->val($section, 'filter')) {
        $filters =~ s/$sub_connection_type/$new_sub_connection_type{$1} \/\/ ''/ge;
        $profiles->newval($section, "filter", $filters);
    }
    if (my $filters = $profiles->val($section, 'advanced_filter')) {
        $filters =~ s/$sub_connection_type/$new_sub_connection_type{$1} \/\/ ''/ge;
        $profiles->newval($section, "advanced_filter", $filters);
    }
}

$profiles->RewriteConfig();

my $vlan_filters = pf::IniFiles->new(-file => $vlan_filters_config_file, -allowempty => 1);

for my $section ($vlan_filters->Sections()) {
    if (my $filters = $vlan_filters->val($section, 'condition')) {
        $filters =~ s/$sub_connection_type/$new_sub_connection_type{$1} \/\/ ''/ge;
        $vlan_filters->newval($section, "condition", $filters);
    }
}

$vlan_filters->RewriteConfig();

my $switch_filters = pf::IniFiles->new(-file => $switch_filters_config_file, -allowempty => 1);

for my $section ($switch_filters->Sections()) {
    if (my $filters = $switch_filters->val($section, 'condition')) {
        $filters =~ s/$sub_connection_type/$new_sub_connection_type{$1} \/\/ ''/ge;
        $switch_filters->newval($section, "condition", $filters);
    }
}

$switch_filters->RewriteConfig();

my $radius_filters = pf::IniFiles->new(-file => $radius_filters_config_file, -allowempty => 1);

for my $section ($radius_filters->Sections()) {
    if (my $filters = $radius_filters->val($section, 'condition')) {
        $filters =~ s/$sub_connection_type/$new_sub_connection_type{$1} \/\/ ''/ge;
        $radius_filters->newval($section, "condition", $filters);
    }
}

$radius_filters->RewriteConfig();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

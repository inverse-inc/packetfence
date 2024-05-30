#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-14.0-adds-admin-roles-fleetdm.pm

=cut

=head1 DESCRIPTION

adds default admin role for FleetDM event webhook

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($admin_roles_config_file);


my $ini = pf::IniFiles->new(-file => $admin_roles_config_file, -allowempty => 1);
my $sectionName = "FleetDM Event Handler";

unless (defined $ini) {
    print("Error loading admin roles config file. Please manually add $sectionName role in Admin UI.\n");
    exit;
}

if ($ini->SectionExists($sectionName)) {
    print("Section '$sectionName' exists, Nothing to do.\n");
    exit 0;
}

$ini->AddSection($sectionName);
$ini->newval($sectionName, 'description' , 'Receives FleetDM events');
$ini->newval($sectionName, 'actions' , 'FLEETDM_EVENTS_READ');
$ini->RewriteConfig();
exit(0);


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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


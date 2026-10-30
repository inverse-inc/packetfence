#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-16.0-connectors-admin-roles.pl

=head1 DESCRIPTION

Grants the CONNECTORS admin actions to the admin roles that managed the
connectors before 16.0.

Before 16.0 the connectors (Configuration > Network Configuration >
Connectors) were covered by the SYSTEM admin actions. They now have their own
CONNECTORS_CREATE, CONNECTORS_READ, CONNECTORS_UPDATE and CONNECTORS_DELETE
actions, so an admin role with SYSTEM_<action> only would lose the connectors
on upgrade: this script adds CONNECTORS_<action> to every role of
adminroles.conf that has SYSTEM_<action> and not CONNECTORS_<action>. Roles
with the ALL action already have them.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($admin_roles_config_file);
use pf::util;

run_as_pf();

unless (-f $admin_roles_config_file) {
    print "No $admin_roles_config_file, nothing to do.\n";
    exit 0;
}

my $ini = pf::IniFiles->new(-file => $admin_roles_config_file, -allowempty => 1)
  or die "Unable to read $admin_roles_config_file\n";

my $changed = 0;
for my $role ($ini->Sections) {
    my $actions = $ini->val($role, 'actions');
    next unless defined $actions && length $actions;
    my @actions = split /\s*,\s*/, $actions;
    next if grep { $_ eq 'ALL' } @actions;
    my %has = map { $_ => 1 } @actions;
    my @added;
    for my $action (qw(CREATE READ UPDATE DELETE)) {
        next unless $has{"SYSTEM_$action"} && !$has{"CONNECTORS_$action"};
        push @actions, "CONNECTORS_$action";
        push @added, "CONNECTORS_$action";
    }
    next unless @added;
    $ini->setval($role, 'actions', join(',', @actions));
    print "Admin role '$role': added @added\n";
    $changed++;
}

if ($changed) {
    $ini->RewriteConfig();
    print "$changed admin role(s) updated in $admin_roles_config_file\n";
} else {
    print "No admin role to update.\n";
}

exit 0;

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

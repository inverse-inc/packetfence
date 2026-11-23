#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-16.0-adds-pki-admin-roles.pl

=cut

=head1 DESCRIPTION

The PKI API (/api/v1/pki/) used to require the SYSTEM admin actions and now
requires the PKI ones. Gives each admin role the PKI_<X> action for each
SYSTEM_<X> action it has, so it keeps its access to the PKI.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($admin_roles_config_file);

my %pki_actions = map { ("SYSTEM_$_" => "PKI_$_") } qw(READ CREATE UPDATE DELETE);

unless (-e $admin_roles_config_file) {
    print("No admin roles config file, nothing to do.\n");
    exit 0;
}

my $ini = pf::IniFiles->new(-file => $admin_roles_config_file, -allowempty => 1);
unless (defined $ini) {
    print("Error loading the admin roles config file. Add the PKI actions matching the SYSTEM actions of the admin roles in the Admin UI.\n");
    exit 1;
}

my $changed = 0;
for my $section ($ini->Sections()) {
    my $value = $ini->val($section, 'actions');
    next unless defined $value;
    my @actions = grep { length } split(/\s*,\s*/, $value);
    my %has = map { $_ => 1 } @actions;
    my @added = grep { !$has{$_} } map { $pki_actions{$_} // () } @actions;
    next unless @added;
    $ini->setval($section, 'actions', join(',', @actions, @added));
    print("Admin role '$section': added " . join(', ', @added) . "\n");
    $changed = 1;
}

if ($changed) {
    $ini->RewriteConfig();
} else {
    print("No admin role needs the PKI actions, nothing to do.\n");
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


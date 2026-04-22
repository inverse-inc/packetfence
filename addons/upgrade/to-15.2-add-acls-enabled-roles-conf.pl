#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-15.2-add-acls-enabled-roles-conf.pl

=cut

=head1 DESCRIPTION

Add acls_enabled=enabled to all existing roles in roles.conf

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($roles_config_file);

my $ini = pf::IniFiles->new(-file => $roles_config_file, -allowempty => 1);

unless (defined $ini) {
    print("Error loading roles config file. Skipping.\n");
    exit 0;
}

my $changed = 0;
for my $section ($ini->Sections()) {
    if (!$ini->exists($section, 'acls_enabled')) {
        print("Setting acls_enabled=enabled for role '$section'\n");
        $ini->newval($section, 'acls_enabled', 'enabled');
        $changed = 1;
    }
}

if ($changed) {
    $ini->RewriteConfig();
    print("Done.\n");
} else {
    print("Nothing to do. All roles already have acls_enabled set.\n");
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

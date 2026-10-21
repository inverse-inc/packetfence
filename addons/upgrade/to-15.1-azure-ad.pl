#!/usr/bin/perl

=head1 NAME

Azure AD Configuration Migration Script - Migrates and updates Azure AD authentication configuration entries

=head1 DESCRIPTION

This script migrates Azure AD configurations in the authentication INI file. It
splits the legacy C<user_groups_url> field into the new C<graph_url> (scheme +
host) and C<user_groups_url_path> (path with C<%USERNAME> substitution) fields.

When the legacy path differs from the v15.0 default
C</v1.0/users/%USERNAME/memberOf> (for example, customers who pointed at
C</v1.0/devices(deviceId='%USERNAME')/memberOf> to look up device/machine
group memberships), the customization is preserved in C<user_groups_url_path>
so the source keeps behaving the way it did pre-upgrade.

The script is idempotent: it skips sections that have already been migrated.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::constants::config;
use pf::constants qw ($TRUE $FALSE);
use pf::file_paths qw(
    $authentication_config_file
);

my $DEFAULT_PATH = '/v1.0/users/%USERNAME/memberOf';

my $ini = pf::IniFiles->new( -file => $authentication_config_file, -allowempty => 1);
my $changed = 0;

for my $section ($ini->Sections) {
    my $type = $ini->val($section, 'type');
    next if !defined $type || $type ne 'AzureAD';
    my $user_groups_url = $ini->val($section, 'user_groups_url');
    next if !defined $user_groups_url;
    print "Updating section $section\n";

    my ($base, $path);
    if ($user_groups_url =~ m{^(https?://[^/]+)(/.*)?$}) {
        $base = $1;
        $path = defined $2 && length $2 ? $2 : $DEFAULT_PATH;
    } else {
        # Unparseable URL - fall back to leaving graph_url empty so the
        # source uses its compiled-in default, and just preserve the raw
        # value as the path for the operator to fix up manually.
        $base = '';
        $path = $user_groups_url;
    }

    $ini->newval($section, 'graph_url', $base) if length $base;
    if ($path ne $DEFAULT_PATH) {
        $ini->newval($section, 'user_groups_url_path', $path);
    }
    $ini->delval($section, 'user_groups_url');
    $changed |= 1;
}

if ($changed) {
    $ini->RewriteConfig();
} else {
    print "Nothing to do\n";
}

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

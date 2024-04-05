#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-13.2-upgrade-domain-config.pl

=cut

=head1 DESCRIPTION

adds nt key caching related options and parameters.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($domain_config_file);
use pf::util;
use pf::cluster qw($cluster_enabled $host_id);;

my $ini = pf::IniFiles->new(-file => $domain_config_file, -allowempty => 1);

unless (defined $ini) {
    print("Error loading domain config file. Terminated. Try re-run this script or edit domain settings in admin UI manually. /\n");
    exit;
}

my $updated = 0;

for my $section (grep {/^\S+$/} $ini->Sections()) {
    print("Updating config for section: $section\n");

    if ($ini->exists($section, 'nt_key_cache_enabled')) {
        print("  Section: ", $section, " is already up to date. Skipped.\n");
        next;
    } else {
        $ini->newval($section, 'nt_key_cache_enabled', 'False');
        $ini->newval($section, 'ad_account_lockout_threshold', '0');
        $ini->newval($section, 'ad_account_lockout_duration', '0');
        $ini->newval($section, 'ad_reset_account_lockout_counter_after', '0');
        $ini->newval($section, 'ad_old_password_allowed_period', '0');
        $ini->newval($section, 'max_allowed_password_attempts_per_device', '0');
        $ini->newval($section, 'ad_minimum_password_age', '1');

        $updated = 1;
    }
}

if ($updated == 1) {
    $ini->RewriteConfig();
}



=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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


#!/usr/bin/perl

=head1 NAME

firewallsso_to_update -

=head1 DESCRIPTION

firewallsso_to_update

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::constants::config;
use pf::constants qw ($TRUE $FALSE);
use pf::file_paths qw(
    $firewall_sso_config_file
    $pf_config_file
    $pf_default_file
);


my $fsso = pf::IniFiles->new( -file => $firewall_sso_config_file, -allowempty => 1);

my $config = pf::IniFiles->new(-file => $pf_config_file, -allowempty => 1 );

my $default_pf_config =  pf::IniFiles->new(-file => $pf_default_file, -allowempty => 1);


my $sso_on_access_reevaluation;

if ($config->exists('advanced', 'sso_on_access_reevaluation')) {
    $sso_on_access_reevaluation = $config->val('advanced', 'sso_on_access_reevaluation');
} else {
    $sso_on_access_reevaluation = $FALSE;
}


my $sso_on_dhcp;

if ($config->exists('advanced', 'sso_on_dhcp')) {
    $sso_on_dhcp = $config->val('advanced', 'sso_on_dhcp');
} else {
    $sso_on_dhcp = $TRUE;
}

my $sso_on_accounting;

if ($config->exists('advanced', 'sso_on_accounting')) {
    $sso_on_accounting = $config->val('advanced', 'sso_on_accounting');
} else {
    $sso_on_accounting = $FALSE;
}

if (length ($fsso->Sections()) > 0) {
    for my $section ($fsso->Sections()) {
        if (!($fsso->exists($section, "sso_on_access_reevaluation"))) {
            $fsso->newval($section, 'sso_on_access_reevaluation', $sso_on_access_reevaluation);
        } else {
            print "The section $section has already the option sso_on_access_reevaluation defined"
        }
        if (!($fsso->exists($section, "sso_on_dhcp"))) {
            $fsso->newval($section, 'sso_on_dhcp', $sso_on_dhcp);
        } else {
            print "The section $section has already the option sso_on_dhcp defined"
        }
        if (!($fsso->exists($section, "sso_on_accounting"))) {
            $fsso->newval($section, 'sso_on_accounting', $sso_on_accounting);
        } else {
            print "The section $section has already the option sso_on_accounting defined"
        }
    }
    $fsso->RewriteConfig();
} else {
    print "Nothing to do\n";
}

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

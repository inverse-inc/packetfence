#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-8.3-rename-pf-conf-parameters.pl

=cut

=head1 DESCRIPTION

Rename old config items

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::file_paths qw($pf_config_file $security_events_config_file);
use pf::util;
run_as_pf();

my %rename = (
    'advanced.record_accounting_in_sql' => 'radius_configuration.record_accounting_in_sql',
    'advanced.ntlm_redis_cache'         => 'radius_configuration.ntlm_redis_cache',
    'advanced.radius_attributes'        => 'radius_configuration.radius_attributes',
    'advanced.normalize_radius_machine_auth_username' => 'radius_configuration.normalize_radius_machine_auth_username',
);


my $ini = pf::IniFiles->new(-file => $pf_config_file, -allowempty => 1);
if ($ini ) {
    if ($ini->SectionExists('radius_authentication_methods')) {
        $ini->RenameSection('radius_authentication_methods', 'radius_configuration');
    }

    while (my ($old, $new) = each %rename) {
        my ($old_s, $old_p) = split(/\./, $old);
        next unless $ini->exists($old_s, $old_p);
        my $val = $ini->val($old_s, $old_p);
        $ini->delval($old_s, $old_p);
        my ($new_s, $new_p) = split(/\./, $new);
        $ini->newval($new_s, $new_p, $val);
    }


    $ini->DeleteSection();
    $ini->RewriteConfig();
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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


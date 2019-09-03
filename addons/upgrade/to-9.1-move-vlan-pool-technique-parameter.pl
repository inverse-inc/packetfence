#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-9.1-move-vlan-pool-technique-parameter.pl

=cut

=head1 DESCRIPTION

Move vlan_pool_technique parameter in profiles.conf

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::file_paths qw($pf_config_file $pf_default_file $profiles_config_file $profiles_default_config_file);
use pf::util;
run_as_pf();

my $ini = pf::IniFiles->new(-file => $pf_config_file, -allowempty => 1);
my $profiles = pf::IniFiles->new(-file => $profiles_config_file, -allowempty => 1);
my $profiles_default = pf::IniFiles->new(-file => $profiles_default_config_file, -allowempty => 1);
unless ($ini) {
    exit;
}

if (!$ini->exists('advanced', 'vlan_pool_technique')) {
    exit;
}

my $val = $ini->val('advanced', 'vlan_pool_technique');
$ini->delval('advanced', 'vlan_pool_technique');
my $cur_val = $profiles_default->val('default', 'vlan_pool_technique');
print "'$cur_val' ne '$val'\n";
if ($cur_val ne $val) {
    $profiles->newval('default', 'vlan_pool_technique', $val);
    $profiles->RewriteConfig();
}
$ini->RewriteConfig();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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


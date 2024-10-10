#!/usr/bin/perl

=head1 NAME

to-10.3-roles-acls.pl -

=head1 DESCRIPTION

Migrate the ACLs from the switches to all.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use Data::Dumper;
use pf::file_paths qw(
    $provisioning_config_file
);

my $ini = pf::IniFiles->new(-file => $provisioning_config_file, -allowempty => 1);
my $ini_updated = 0;
for my $section ($ini->Sections()) {
    next if $ini->val($section, 'type') ne 'sentinelone';
    next if !$ini->exists($section, 'win_agent_download_uri');
    print "Migrating $section\n";
    my $old_val = $ini->val($section, 'win_agent_download_uri');
    $ini->delval($section, 'win_agent_download_uri');
    $ini->newval($section, 'windows_agent_download_uri', $old_val);
    $ini_updated |= 1;
}

if ($ini_updated) {
    $ini->RewriteConfig();
    print "All done\n";
} else {
    print "Nothing to be done\n";
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

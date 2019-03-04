#!/usr/bin/perl

=head1 NAME

to-7.3-adminroles-conf.pl

=cut

=head1 DESCRIPTION

Remove references to USERAGENTS_READ in adminroles.conf if there are any

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::file_paths qw($admin_roles_config_file);
use List::MoreUtils qw(any);
use pf::util;

run_as_pf();

exit 0 unless -e $admin_roles_config_file;
my $ini = pf::IniFiles->new(-file => $admin_roles_config_file, -allowempty => 1);

for my $section ($ini->Sections()) {
    if (my $actions = $ini->val($section, 'actions')) {
        $actions = [ split(/\s*,\s*/, $actions) ];
        if(any {$_ eq "USERAGENTS_READ"} @$actions) {
            print "Removing USERAGENTS_READ from actions in section $section\n";
            $actions = [ map { $_ ne "USERAGENTS_READ" ? $_ : () } @$actions ];
            $ini->setval($section, 'actions', join(',', @$actions));
        }
    }
}

$ini->RewriteConfig();

print "All done\n";

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


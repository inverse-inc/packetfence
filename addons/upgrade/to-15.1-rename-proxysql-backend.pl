#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-15.1-rename-proxysql-backend.pl

=cut

=head1 DESCRIPTION

Rename database_proxysql.backend to database_proxysql.backends in pf.conf

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($pf_config_file);
use pf::util;
run_as_pf();

my $ini = pf::IniFiles->new(-file => $pf_config_file, -allowempty => 1);

if ($ini && $ini->exists('database_proxysql', 'backend')) {
    my $val = $ini->val('database_proxysql', 'backend');
    $ini->delval('database_proxysql', 'backend');
    $ini->newval('database_proxysql', 'backends', $val);
    $ini->RewriteConfig();
    print("Renamed database_proxysql.backend to database_proxysql.backends\n");
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

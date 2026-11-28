#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-16.0-openvas-gmp-ssh.pl

=cut

=head1 DESCRIPTION

Move the OpenVAS scan engines of scan.conf to GMP over SSH: the omp TLS port 9390 becomes the SSH port 22
and the report format ID is removed, since the report is now read in XML

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($scan_config_file);
use pf::util;

run_as_pf();

exit 0 if !-e $scan_config_file;

my $ini = pf::IniFiles->new(-file => $scan_config_file, -allowempty => 1);
exit 0 if !$ini;

my $changed = 0;
for my $section ($ini->Sections()) {
    next if ($ini->val($section, 'type') // '') ne 'openvas';
    if ($ini->exists($section, 'openvas_reportformatid')) {
        $ini->delval($section, 'openvas_reportformatid');
        $changed = 1;
    }
    my $port = $ini->val($section, 'port');
    if (!defined $port || $port eq '9390') {
        $ini->exists($section, 'port') ? $ini->setval($section, 'port', 22) : $ini->newval($section, 'port', 22);
        $changed = 1;
        print("Scan engine $section now reaches the GMP service over SSH on port 22\n");
    }
}

$ini->RewriteConfig() if $changed;

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

1;

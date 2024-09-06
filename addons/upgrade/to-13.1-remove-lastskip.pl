#!/usr/bin/perl

=head1 NAME

to-13.1-remove-lastskip.pl

=cut

=head1 DESCRIPTION

Remove references to lastskip in report.conf if there are any

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($report_config_file);
use List::MoreUtils qw(any);
use pf::util;

run_as_pf();

exit 0 unless -e $report_config_file;
my  $report_ini = pf::IniFiles->new(-file => $report_config_file, -allowempty => 1);

for my $section ($report_ini->Sections()) {
    if (my $columns = $report_ini->val($section, 'columns')) {
        $columns = [ split(/\s*,\s*/, $columns) ];
        if(any {$_ eq "lastskip"} @$columns) {
            print "Removing lastskip from columns in section $section\n";
            $columns = [ map { $_ ne "lastskip" ? $_ : () } @$columns ];
            $report_ini->setval($section, 'columns', join(',', @$columns));
        }
    }
}

$report_ini->RewriteConfig();

print "All done\n";

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


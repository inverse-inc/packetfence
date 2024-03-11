#!/usr/bin/perl

=head1 NAME

pfmon_to_maintenance -

=head1 DESCRIPTION

pfmon_to_maintenance

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::constants::config;
use pf::file_paths qw(
    $cron_config_file
);

my $pfcron = pf::IniFiles->new( -file => $cron_config_file, -allowempty => 1);
my $section = 'bandwidth_maintenance_session';
my $to_section2 = 'bandwidth_maintenance';
if ($pfcron->SectionExists($section)) {
    for my $f (qw(batch window timeout)) {
        if ($pfcron->exists($section, $f)) {
            print "Moving $section.$f -> $to_section2.session_$f\n";
            $pfcron->newval($to_section2, "session_$f", $pfcron->val($section, $f));
        }
    }
    $pfcron->DeleteSection($section);
    $pfcron->RewriteConfig();
    print "Remove $section\n";
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

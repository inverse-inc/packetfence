#!/usr/bin/perl

=head1 NAME

to-10.2-selfservice-conf.pl

=cut

=head1 DESCRIPTION

Rename device_registration_role to device_registration_roles

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $self_service_config_file
);
use List::MoreUtils qw(any);
use pf::util;
use File::Copy;

run_as_pf();

my $ss_ini = pf::IniFiles->new(-file => $self_service_config_file, -allowempty => 1);

my %remap = (
    device_registration_role => "device_registration_roles",
);
for my $section ($ss_ini->Sections()) {
    while(my ($old, $new) = each(%remap)) {
        print "Renaming parameter $old to $new in section $section in file $self_service_config_file \n";
        my $val = $ss_ini->val($section, $old);
        $ss_ini->newval($section, $new, $val);
        $ss_ini->delval($section, $old);
    }
}

$ss_ini->RewriteConfig();

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



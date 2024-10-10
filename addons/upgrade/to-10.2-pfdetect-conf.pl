#!/usr/bin/perl

=head1 NAME

to-10.2-pfdetect-conf -

=head1 DESCRIPTION

Add the new field tenant_id to the detect parsers

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $pfdetect_config_file
);

my ($login,$pass,$uid,$gid) = getpwnam('pf');
chown $uid, $gid, $pfdetect_config_file;

use pf::util;
run_as_pf();

my $ini = pf::IniFiles->new(-file => $pfdetect_config_file, -allowempty => 1);
my $i = 0;

for my $section (grep { !/\s/  } $ini->Sections()) {
    next if $ini->exists($section, 'tenant_id'); 
    print "Adding the tenant_id to $section\n";
    $ini->newval($section, 'tenant_id' , 1);
    $i |= 1;
}

if ($i) {
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


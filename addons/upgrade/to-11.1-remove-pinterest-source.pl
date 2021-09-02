#!/usr/bin/perl

=head1 NAME

to-11.1-remove-pinterest-source -

=head1 DESCRIPTION

to-11.1-remove-pinterest-source

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($authentication_config_file);
use pf::util;

my $file = $authentication_config_file;
if (@ARGV) {
    $file = $ARGV[0];
}

my $typeToDelete = 'Pinterest';
my $cs = pf::IniFiles->new(-file => $file, -allowempty => 1);
my $update = 0;

for my $section ( grep {/^\S+$/} $cs->Sections() ) {
    my $type = $cs->val($section, 'type');
    if ($type eq $typeToDelete) {
        $cs->DeleteSection($section);
        for my $group ($cs->GroupMembers($section)) {
            $cs->DeleteSection($group);
        }

        $update |= 1;
        print "Removing $section\n";
    }
}

if ($update) {
    $cs->RewriteConfig();
    print "All done\n";
    exit 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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


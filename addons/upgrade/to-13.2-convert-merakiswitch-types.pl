#!/usr/bin/perl

=head1 NAME

to-13.2-convert-merakiswitch-types.pl

=head1 DESCRIPTION

Convert some switch types and use Switch OS versions

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $switches_config_file
);
use pf::util qw(run_as_pf);
run_as_pf();

my $file = $switches_config_file;

if (@ARGV) {
    $file = $ARGV[0];
}

our %types = (
    'Meraki::MS220_8' => 'Meraki::MS_v15',
);

my $cs = pf::IniFiles->new(-file => $file, -allowempty => 1);

my $update = 0;
for my $section ($cs->Sections()) {
    my $type = $cs->val($section, 'type');
    next if !defined $type || !exists $types{$type};
    my $new_type = $types{$type};
    $cs->setval($section, 'type', $new_type);
    $update |= 1;
}

if ($update) {
    $cs->RewriteConfig();
    print "All done\n";
    exit 0;
}


print "Nothing to be done\n";

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


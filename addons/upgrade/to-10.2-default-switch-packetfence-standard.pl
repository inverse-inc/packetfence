#!/usr/bin/perl

=head1 NAME

to-10.2-default-switch-packetfence-standard.pl

=cut

=head1 DESCRIPTION

Add Generic type where needed

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $switches_config_file
);
use List::MoreUtils qw(any);
use pf::util;
use File::Copy;

run_as_pf();

my $file = $switches_config_file;

if (@ARGV) {
    $file = $ARGV[0];
}

my $cs = pf::IniFiles->new(-file => $file, -allowempty => 1);
my @groups;
my @switches;

my $default_type = $cs->val('default', 'type');

if ($default_type && $default_type ne 'Generic') {
    print "Nothing to do\n";
    exit;
}

for my $section ($cs->Sections()) {
    next if $section eq 'default';
    if ($section =~ /^group /) {
        push @groups, $section;
    } else {
        push @switches, $section;
    }
}

for my $group (@groups) {
    if (!$cs->exists($group, 'type')) {
        print "$group: setting type to Generic\n";
        $cs->newval($group, 'type', 'Generic');
    }
}

for my $sw (@switches) {
    if (!$cs->exists($sw, 'type') && (!$cs->exists($sw, 'group') || $cs->val($sw, 'group') eq 'default')) {
        print "$sw setting type to Generic\n";
        $cs->newval($sw, 'type', 'Generic');
    }
}

$cs->RewriteConfig();

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



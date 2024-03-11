#!/usr/bin/perl

=head1 NAME

to-10.1-radius-filter-template -

=head1 DESCRIPTION

to-10.1-radius-filter-template

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use File::Copy;
use pf::condition_parser qw(parse_condition_string);
use pf::util::console;
use pf::file_paths qw(
    $radius_filters_config_file
);

my $COLORS = pf::util::console::colors();
my $old_ext = "old_pre_v10.1";
my $changed = 0;
our $indent = "  ";

my $file = $radius_filters_config_file;

sub rangeValidator {
    my ($range) =@_;
    my $rangesep = qr/(?:\.\.)/;
    my $sectsep  = qr/(?:\s|,)/;
    my $validation = qr/(?:
         [^0-9,. -]|
         $rangesep$sectsep|
         $sectsep$rangesep|
         \d-\d|
         ^$sectsep|
         ^$rangesep|
         $sectsep$|
         $rangesep$|
         ^\d+$
         )/x;
    return 0 if ($range =~ m/$validation/g);
    return 1;
}


print "Upgrading $file to the new format\n";
my $cs = pf::IniFiles->new( -file => $file, -allowempty => 1, );
for my $s ($cs->Sections()) {
    for my $p ( grep { $_ =~ /^answer/} $cs->Parameters($s)) {
        my $a = $cs->val($s, $p);
        my ($name, $val) = split(/\s*=\s*/, $a, 2);
        if (rangeValidator($val)) {
            $val = "\${random_from_range(\"$val\")}";
            $changed |= 1;
        }
        $cs->setval($s, $p, $val);
    }
}

if ($changed) {
    my $old_file = "$file.$old_ext";
    copy($file, $old_file);
    print "${indent}Old config is located $old_file\n\n";
    $cs->WriteConfig($file);
} else {
    print "${indent}Nothing changed skipping\n"
}

print "Done\n";

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


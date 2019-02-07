#!/usr/bin/perl

=head1 NAME

to-8.2-pfdetect-conf.pl

=cut

=head1 DESCRIPTION

Upgrade

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::file_paths qw($pfdetect_config_file);
use pf::util;
run_as_pf();
my $prefix = "   ";
my $ini = pf::IniFiles->new(-file => $pfdetect_config_file, -allowempty => 1);
for my $section ( grep { / rule / } $ini->Sections()) {
    next unless $ini->exists($section, "regex");
    print "Upgrading $section\n";
    my $regex = $ini->val($section, "regex");
    {
        use re::engine::RE2 -strict => 1;
        eval {qr/$regex/};
        if ($@) {
            print "  Fixing $regex\n";
            my $new_regex = $regex;
            $new_regex =~ s/\(\?\<([_A-Za-z][_A-Za-z0-9]*)\>/(?P<$1>/g;
            $new_regex =~ s/\(\?'([_A-Za-z][_A-Za-z0-9]*)'/(?P<$1>/g;
            eval {qr/$new_regex/};
            if ($@) {
                my $error = $@;
                $error =~ s/^/$prefix/;
                $error =~ s/\n/\n$prefix/;
                $error =~ s/\Q$prefix\E$//;
                print STDERR "${prefix}The regex /$regex/ could not be upgraded to RE2\n$error\n";
            } else {
                $ini->setval($section, "regex", $new_regex);
            }
        }
    }
}

$ini->RewriteConfig();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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


#!/usr/bin/perl

=head1 NAME

to-11.1-remove-wmi-scan.pl

=head1 DESCRIPTION

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $report_config_file
);

use pf::util;

main() if not caller();

sub main {
    if (updateReport($report_config_file)) {
        print "All done\n";
        return;
    }

    print "Nothing to be done\n";

}

sub updateReport {
    my ($file) = @_;
    my $cs = pf::IniFiles->new(-file => $file, -allowempty => 1);
    my $updated = 0;
    for my $section ( grep {/^\S+$/} $cs->Sections() ) {
        if ($cs->exists($section, 'type')) {
            my $type = $cs->val($section, 'type');
            if ($type eq 'abstract' || $type eq 'sql') {
                next;
            }

            $cs->setval($section, 'type', 'abstract');
        } else {
            $cs->newval($section, 'type', 'abstract');
        }

        $updated |= 1;
    }

    if ($updated) {
        $cs->RewriteConfig();
    }

    return $updated;
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

1;

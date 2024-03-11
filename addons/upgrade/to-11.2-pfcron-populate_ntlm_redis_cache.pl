#!/usr/bin/perl

=head1 NAME

to-11.2-pfcron-populate_ntlm_redis_cache.pl

=head1 DESCRIPTION

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $cron_config_file
);

main($cron_config_file) if not caller();

sub main {
    my ($file) = @_;
    my $cs = pf::IniFiles->new(-file => $file, -allowempty => 1);
    my $update = 0;
    my $section = 'populate_ntlm_redis_cache';
    if ($cs->SectionExists($section)) {
        $cs->DeleteSection($section);
        $update = 1;
    }

    if (!$update) {
        print "Nothing to be done\n";
        exit 0;
    }

    $cs->RewriteConfig();
    print "All done\n";
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

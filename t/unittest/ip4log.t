#!/usr/bin/perl

=head1 NAME

ip4log

=cut

=head1 DESCRIPTION

unit test for ip4log

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 2;

#This test will running last
use Test::NoWarnings;
use pf::ip4log;
use pf::dal::ip4log_archive;
use pf::dal::ip4log_history;

my @iplogs = (
    {
        mac        => "ff:ff:ff:ee:ee:ee",
        ip         => "1.2.3.4",
        start_time => \[ 'DATE_SUB(NOW(), INTERVAL ? SECOND)', 20 ],
        end_time => \[ 'DATE_SUB(NOW(), INTERVAL ? SECOND)', 10 ],
    },
);

pf::dal::ip4log_history->remove_items();
pf::dal::ip4log_archive->remove_items();

for my $iplog (@iplogs) {
    pf::dal::ip4log_history->create($iplog);
}

pf::ip4log::rotate(1, 10, 1);

my ($status, $iter) = pf::dal::ip4log_archive->search(
    -where => { ip => "1.2.3.4"}
);

is($iter->rows, 1, "One item moved from the the history table to the archive");

pf::dal::ip4log_history->remove_items();
pf::dal::ip4log_archive->remove_items();

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

1;

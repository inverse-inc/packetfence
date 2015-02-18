#!/usr/bin/perl
=head1 NAME

chi_stats_memcache_vs_dbi add documentation

=cut

=head1 DESCRIPTION

chi_stats_memcache_vs_dbi

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);

use Benchmark;
use CHI;
use DBI;
use pf::db;
use File::Slurp;

my $chi_memcache = CHI->new(
    driver => 'Memcached',
    servers => [qw(127.0.0.1:11211)],
    compress_threshold => 1000000,
    namespace => 'chistats',
);

my $chi_DBI = CHI->new(
    driver => 'DBI',
    dbh => \&db_connect,
    namespace => 'chistats',
    compress_threshold => 1000000,
);

print $chi_DBI->_table,"\n";

my $TIMES = 100 ;

my $data = read_file('/usr/local/pf/t/chi-stats/dummy.dat');

for my $i (1..$TIMES) {
    $chi_memcache->set($i,$data);
    $chi_DBI->set($i,$data);
}

my ($key1,$key2) = (1,1);

timethese (-5, {
        'Test 1 chi Memcached' => sub {
            my $data = $chi_memcache->get($key1);
            $key1++;
            $key1 %= $TIMES;
        },
        'Test 2 chi DBI' => sub {
            my $data = $chi_DBI->get($key2);
            $key2 %= $TIMES;
        },
});


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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


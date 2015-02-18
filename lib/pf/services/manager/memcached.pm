package pf::services::manager::memcached;
=head1 NAME

pf::services::manager::memcached add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::memcached

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths;
use pf::config;

extends 'pf::services::manager';

has '+name' => (default => sub { 'memcached' } );

has '+launcher' => (default => sub {
    my $memcached_memory_usage = $Config{services}{memcached_memory_usage};
    my $memcached_max_item_size = $Config{services}{memcached_max_item_size};
    "%1\$s -d -p 11211 -u pf -m $memcached_memory_usage -I $memcached_max_item_size -c 1024 -P $install_dir/var/run/memcached.pid"
});

has '+shouldCheckup' => ( default => sub { 0 }  );

has '+dependsOnServices' => (is => 'ro', default => sub { [] } );

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

1;


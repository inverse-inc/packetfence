package pf::Syslog;

=head1 NAME

pf::Syslog -

=head1 DESCRIPTION

pf::Syslog

=cut

use strict;
use warnings;
use CHI;
use Log::Any::Adapter;
Log::Any::Adapter->set('Log4perl');
use pf::AtFork;
use Net::Syslog;

our $CHI_CACHE = CHI->new(driver => 'RawMemory', datastore => {});

=head2 new

Will create a Redis::Fast connection or a shared one

=cut

sub new {
    my ($self, $key, $args) = @_;
    return $CHI_CACHE->compute($key, sub { return Net::Syslog->new(%$args) });
}

=head2 CLONE

Will clear out the redis cache

=cut

sub CLONE {
    $CHI_CACHE->clear;
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

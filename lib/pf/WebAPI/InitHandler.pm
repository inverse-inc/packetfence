package pf::WebAPI::InitHandler;
=head1 NAME

pf::WebAPI::InitHandler

=cut

=head1 DESCRIPTION

pf::WebAPI::InitHandler

=cut

use strict;
use warnings;

use Apache2::RequestRec ();
use pf::config::cached;
use pf::db;
use pf::CHI;
use Cache::Memcached;

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;
    pf::config::cached::RefreshConfigs();
    return Apache2::Const::OK;
}


=head2 post_config

Reset all cached connections before initializing children

=cut

sub post_config {
    my ($conf_pool, $log_pool, $temp_pool, $s) = @_;
    pf::config::cached::RefreshConfigs();
    db_disconnect();
    pf::CHI->clear_memoized_cache_objects;
    Cache::Memcached->disconnect_all;
    return Apache2::Const::OK;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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


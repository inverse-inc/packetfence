package pf::services::manager::connector_cache;

=head1 NAME

pf::services::manager::connector_cache

=cut

=head1 DESCRIPTION

pf::services::manager::connector_cache
packetfence-connector-cache daemon manager module for PacketFence.

It caches the answers of the remote RADIUS servers of the realms with the
degraded mode enabled, they are replayed when all of them are dead.

=cut

use strict;
use warnings;
use Moo;
use List::MoreUtils qw(any);
use pf::util;

extends 'pf::services::manager';

has '+name'     => ( default => sub { 'connector-cache' } );

our $BINARY = '/usr/sbin/connector-cache';

=head2 isManaged

Only managed when packetfence-connector-cache is installed and a realm proxying
the authentication has the degraded mode enabled

=cut

sub isManaged {
    my ($self) = @_;
    require pf::config;
    return $self->SUPER::isManaged() && -x $BINARY && any {
        my $realm = $pf::config::ConfigRealm{$_};
        $realm->{radius_auth} && isenabled($realm->{radius_degraded})
    } keys %pf::config::ConfigRealm;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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


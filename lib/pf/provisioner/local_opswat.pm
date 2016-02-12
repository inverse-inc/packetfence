package pf::provisioner::local_opswat;
=head1 NAME

pf::provisioner::opswat add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::opswat

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use pf::log;
use pf::node;
use pf::config;
use pfconfig::config;

=head1 Atrributes

=head2 licensing_host

Host of the licensing web API

=cut

has licensing_host => (is => 'rw', required => 1);

has reporting_host => (is => 'rw', default => $fqdn);

has agent_update_url => (is => 'rw', default => "https://gears.opswat.com/agent/update");

has max_ping => (is => 'rw', default => 1800);

=head2 authorize

Only checking ping as the handling of the report is made in PacketFence.

=cut

sub authorize {
    my ($self,$mac) = @_;
    my $logger = get_logger();

    my $node_view = node_view($mac);
    my $device_id = $node_view->{device_id};

    unless($device_id){
        $logger->info("Can't find device ID for $mac.");
        return $FALSE;
    }

    my $backend = pfconfig::config->new->get_backend();
    my $ping_key = $device_id."-last-ping";
    my $previous_ping = $backend->get($ping_key);

    my $ping_delay = time - $previous_ping;
    if($ping_delay > $self->max_ping){
        $logger->info("Device $device_id ($mac) is not active anymore. Seen $ping_delay seconds ago.");
        return $FALSE;
    }

    return $TRUE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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


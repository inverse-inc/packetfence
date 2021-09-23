package pf::provisioner::kandji;
=head1 NAME

pf::provisioner::kandji add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::kandji

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use pf::constants;

=head1 Atrributes

=head2 api_token

API token to connect to the API

=cut

has api_token => (is => 'rw', required => $TRUE);

=head2 host

Host of the web API

=cut

has host => (is => 'rw', required => $TRUE);

=head2 port

Port to connect to the web API

=cut

has port => (is => 'rw', default => sub { 443 });

=head2 protocol

Protocol to connect to the web API

=cut

has protocol => (is => 'rw', default => sub { "https" } );

=head2 enroll_url

The URL provided to end users so that they can enroll their devices (self-service enrollment portal of Kandji)
Defaults to $protocol://$host:$port/enroll if none is specified

=cut

has enroll_url => (is => 'rw', builder => 1, lazy => 1);

sub _build_enroll_url {
    my ($self) = @_;
    return $self->{enroll_url} || $self->protocol."://".$self->host.":".$self->port."/enroll"
}

sub authorize {
    my ($self,$mac) = @_;
    return $FALSE;
}

=head2 logger

Return the current logger for the provisioner

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

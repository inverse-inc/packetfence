package pf::constants::switch;

=head1 NAME

pf::constants::switch add documentation

=cut

=head1 DESCRIPTION

pf::constants::switch

=cut

use strict;
use warnings;
use base qw(Exporter);
use Readonly;

our @EXPORT_OK = qw(
    $DEFAULT_ACL_TEMPLATE
    $HOST_MODE_SINGLE_HOST
    $HOST_MODE_MULTI_HOST
    $HOST_MODE_MULTI_AUTH
    $HOST_MODE_MULTI_DOMAIN
    @HOST_MODES
);

Readonly::Scalar our $DEFAULT_ACL_TEMPLATE => '${if($allow, "permit", "deny")} $proto ${if($src_host, join(" ", "host", $src_host), "any")} ${if($src_port, join(" ", "eq", $src_port), "")} ${if($dst_host, join(" ", "host", $dst_host), "any")} ${if($dst_port, join(" ", "eq", $dst_port), "")}';

=head2 Port host modes

The host mode configured on the switch ports. Mirrors the Cisco IOS
C<authentication host-mode> / C<access-session host-mode> values.

Only C<multi-auth> changes PacketFence's behavior:

=over

=item * C<single-host> a single endpoint authenticates on the port.

=item * C<multi-host> the first endpoint authenticates and the others ride the
authorized port. PacketFence only ever sees the first MAC, so a port-wide
deauthentication is the correct thing to do.

=item * C<multi-auth> every endpoint authenticates independently and owns its
RADIUS session. PacketFence keeps one locationlog entry per MAC and
deauthenticates each endpoint individually.

=item * C<multi-domain> one data endpoint plus one voice endpoint. Already
covered by the existing VoIP handling.

=back

=cut

Readonly::Scalar our $HOST_MODE_SINGLE_HOST  => 'single-host';
Readonly::Scalar our $HOST_MODE_MULTI_HOST   => 'multi-host';
Readonly::Scalar our $HOST_MODE_MULTI_AUTH   => 'multi-auth';
Readonly::Scalar our $HOST_MODE_MULTI_DOMAIN => 'multi-domain';

Readonly::Array our @HOST_MODES =>
  (
   $HOST_MODE_SINGLE_HOST, $HOST_MODE_MULTI_HOST, $HOST_MODE_MULTI_AUTH, $HOST_MODE_MULTI_DOMAIN,
  );

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



package pf::constants::template_switch;

=head1 NAME

pf::constants::template_switch - constants for template switch

=head1 DESCRIPTION

pf::constants::template_switch

=cut

use strict;
use warnings;

use base qw(Exporter);
our @EXPORT_OK = qw(
  $DISCONNECT_TYPE_COA
  $DISCONNECT_TYPE_DISCONNECT
  $DISCONNECT_TYPE_BOTH
  @RADIUS_ATTRIBUTE_SETS
  @SUPPORTS
);

our $DISCONNECT_TYPE_COA = 'coa';
our $DISCONNECT_TYPE_DISCONNECT = 'disconnect';
our $DISCONNECT_TYPE_BOTH = 'coaOrDisconnect';
our @RADIUS_ATTRIBUTE_SETS = qw(acceptVlan acceptRole reject disconnect coa voip bounce cliAuthorizeRead cliAuthorizeWrite);
our @SUPPORTS = qw(
  RadiusDynamicVlanAssignment
  WiredMacAuth
  WiredDot1x
  WirelessMacAuth
  WirelessDot1x
  RoleBasedEnforcement
);

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

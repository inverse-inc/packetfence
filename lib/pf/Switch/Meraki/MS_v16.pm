package pf::Switch::Meraki::MS_v16;

=head1 NAME

pf::Switch::Meraki::MS_v16

=head1 SYNOPSIS

The pf::Switch::Meraki::MS_v16 module implements an object oriented interface to
manage the connection with MS series switch model.

=head1 STATUS

Developed and tested on a MS220_8P (P standing for PoE) switch

=head1 BUGS AND LIMITATIONS

=head2 Cannot detect VoIP devices

VoIP devices cannot be detected via CDP/LLDP via an SNMP lookup.

=cut

use strict;
use warnings;

use base ('pf::Switch::Meraki::MS');

use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);
use pf::constants;
use pf::util;
use pf::node;
use Try::Tiny;
use pf::Switch::Meraki::MR_v2;

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
sub description { 'Meraki MS v16' }
use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    RadiusVoip
    RoleBasedEnforcement
);


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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

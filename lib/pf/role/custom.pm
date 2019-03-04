package pf::role::custom;

=head1 NAME

pf::role::custom - Object oriented module for VLAN isolation oriented functions

=head1 SYNOPSIS

The pf::role::custom module implements VLAN isolation oriented functions that are custom
to a particular setup.

This module extends pf::role

=cut

use strict;
use warnings;

use pf::log;

use base ('pf::role');

use pf::config;
use pf::node qw(node_attributes node_exist node_modify);
use pf::Switch::constants;
use pf::util;
use pf::security_event qw(security_event_count_reevaluate_access security_event_exist_open security_event_view_top);

use pf::authentication;
use pf::Authentication::constants;
use pf::Connection::ProfileFactory;

our $VERSION = 1.04;


=head1 SUBROUTINES

=cut

=head2 shouldAutoRegister

This is an example of how to redefine a method for custom purposes.

See pf::role::shouldAutoRegister for full original method.

=cut

#sub shouldAutoRegister{
#    #$mac is MAC address
#    #$switch_in_autoreg_mode is set to 1 if switch is in registration mode
#    #$security_event_autoreg is set to 1 if called from a security_event with autoreg action
#    #$isPhone is set to 1 if device is considered an IP Phone.
#    #$conn_type is set to the connnection type expressed as the constant in pf::config
#    #$user_name is set to the RADIUS User-Name attribute (802.1X Username or MAC address under MAC Authentication)
#    #$ssid is set to the wireless ssid (will be empty if radius and not wireless, undef if not radius)
#    my ($self, $mac, $switch_in_autoreg_mode, $security_event_autoreg, $isPhone, $conn_type, $user_name, $ssid, $eap_type, $switch, $port, $radius_request) = @_;
#
#    my $logger = get_logger();
#    # CUSTOM: We want to auto-register 802.1x connections
#    # Since they already have validated credentials through EAP to do 802.1X
#    if (defined($conn_type) && (($conn_type & $EAP) == $EAP)) {
#        $logger->trace("returned yes because it's a 802.1X client that successfully authenticated already");
#        return 1;
#    }
#    # \CUSTOM
#
#    # Otherwise, call parent method
#    return $self->SUPER::shouldAutoRegister($mac, $switch_in_autoreg_mode, $security_event_autoreg, $isPhone, $conn_type, $user_name, $ssid, $eap_type, $switch, $port, $radius_request);
#}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

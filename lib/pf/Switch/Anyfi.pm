package pf::Switch::Anyfi;

=head1 NAME

pf::Switch::Anyfi

=head1 SYNOPSIS

The pf::Switch::Anyfi module implements an object oriented interface to
manage the Anyfi Gateway

=head1 STATUS

Developed and tested on the Anyfi Gateway release R1D (s/w version 1.5.14).

=cut

use strict;
use warnings;

use base ('pf::Switch');

use pf::constants;
use pf::config qw(
    $MAC
    $SSID
);

sub description {"Anyfi Gateway"}

=head1 SUBROUTINES

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=head2 getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->info("we don't know how to determine the version through SNMP !");
    return '1.4.6';
}


=head2 deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1x).

New implementation using RADIUS Disconnect-Request.

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect($mac);
}

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

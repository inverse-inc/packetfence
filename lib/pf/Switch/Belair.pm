package pf::Switch::Belair;

=head1 NAME

pf::Switch::Belair

=head1 SYNOPSIS

The pf::Switch::Belair module implements an object oriented interface to
manage Belair Access Points

=head1 STATUS

Developed and tested on BE20E-11R running firmware 12.0.4 (r38477)

=over

=item Supports

=over

=item Deauthentication with RADIUS Disconnect (RFC3576)

=back

=back

=head1 BUGS AND LIMITATIONS

=over

Works only with firmware 12.0.4 (r38477) or later.

=back

=cut

use strict;
use warnings;

use base ('pf::Switch');

use pf::constants;
use pf::config qw(
    $MAC $SSID
);
use pf::util;

sub description { 'Belair Networks AP' }

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $FALSE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item getVersion

obtain image version information from switch

=cut

sub getVersion {
    my ($self)       = @_;
    my $oid_beActiveBank = '.1.3.6.1.4.1.15768.3.1.1.3.1';
    my $logger       = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_beActiveBank");

    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_beActiveBank] );
    if (defined($result)) {
        #Fetch the active version
        my $oid_beBank = '1.3.6.1.4.1.15768.3.1.1.3.5.1.2.' . $result->{$oid_beActiveBank};
        $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_beBank] );

        if (defined($result)) {
            return $result->{$oid_beBank};
        }
    }

    # none of the above worked
    $logger->warn("unable to fetch version information");
}

=item deauthenticateMacDefault

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

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => 'deauthenticateMacDefault',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}


=back

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

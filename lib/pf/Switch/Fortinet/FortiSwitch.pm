package pf::Switch::Fortinet::FortiSwitch;

=head1 NAME

pf::Switch::Fortinet::FortiSwitch - Object oriented module to FortiSwitch using the 802.1x with the radius disconnect (CoA) on port 3799

=head1 SYNOPSIS

The pf::Switch::Fortinet::FortiSwitch  module implements an object oriented interface to interact with the FortiSwitch

=head1 STATUS

802.1X tested with FortiOS X.X

=cut

=head1 BUGS AND LIMITATIONS


=cut

use strict;
use warnings;
use pf::node;
use pf::violation;
use pf::locationlog;
use pf::util;
use LWP::UserAgent;
use HTTP::Request::Common;
use pf::log;
use pf::constants;
use pf::accounting qw(node_accounting_dynauth_attr);
use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);

use base ('pf::Switch::Fortinet');

=head1 METHODS

=cut

sub description { 'FortiSwitch' }

sub supportsWirelessMacAuth { return $TRUE; }
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacDefault',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::RADIUS;
        my %tech = (
            $SNMP::RADIUS => 'deauthenticateMacDefault',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
}


=item deauthenticateMacDefault

Overrides base method to send Acct-Session-Id, NAS-Identifier and the Called-Station-Id within the RADIUS disconnect request

=cut

sub deauthenticateMacDefault {
    my ( $self, $ifIndex, $mac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    #Fetching the acct-session-id
    my $dynauth = node_accounting_dynauth_attr($mac);

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect(
        $mac, { 'Acct-Session-Id' => $dynauth->{'acctsessionid'}, 'User-Name' => $dynauth->{'username'}, 'NAS-Identifier' => $dynauth->{'nasidentifier'}, 'Called-Station-Id' => $dynauth->{'calledstationid'} },
    );
}

=head2 getVersion

return a constant since there is no api for this

=cut

sub getVersion {
    my ($self) = @_;
    return 0;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

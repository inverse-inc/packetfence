package pf::Switch::Dell::N1500;


=head1 NAME

pf::Switch::Dell::N1500

=head1 SYNOPSIS

pf::Switch::Dell::N1500 module manages access to Dell N1500 Series

=head1 STATUS



=cut

use strict;
use warnings;
use pf::log;

use base ('pf::Switch::Dell');
use pf::constants;
use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
);

sub description { 'N1500 Series' }

# importing switch constants
use pf::Switch::constants;
use pf::util::radius qw(perform_coa);

# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
# VoIP technology supported
sub supportsRadiusVoip { return $TRUE; }
sub supportsRadiusDynamicVlanAssignment { return $TRUE; }
sub supportsLldp { return $TRUE; }

=head2 isVoIPEnabled

Supports VoIP if enabled.

=cut

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

=head2 wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    if ($connection_type == $WIRED_802_1X) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'dot1xPortReauthenticate',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
    if ($connection_type == $WIRED_MAC_AUTH) {
        my $default = $SNMP::SNMP;
        my %tech = (
            $SNMP::SNMP => 'handleReAssignVlanTrapForWiredMacAuth',
            $SNMP::RADIUS => 'deauthenticateMacRadius',
        );

        if (!defined($method) || !defined($tech{$method})) {
            $method = $default;
        }
        return $method,$tech{$method};
    }
}

=head2 dot1xPortReauthenticate


=cut

sub dot1xPortReauthenticate {
    my ($self, $ifIndex, $mac) = @_;

    return $self->_dot1xPortReauthenticate($ifIndex);
}

=head2 returnAuthorizeWrite

Return radius attributes to allow write access (supposed to work)

=cut

sub returnAuthorizeWrite {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{'Cisco-AVPair'} = 'shell:priv-lvl=15';
    $radius_reply_ref->{'Reply-Message'} = "Switch enable access granted by PacketFence";
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with write access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeWrite', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];

}

=head2 returnAuthorizeRead

Return radius attributes to allow read access (supposed to work)

=cut

sub returnAuthorizeRead {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    my $radius_reply_ref;
    my $status;
    $radius_reply_ref->{'Cisco-AVPair'} = 'shell:priv-lvl=3';
    $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
    $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnAuthorizeRead', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}


=head2 getPhonesLLDPAtIfIndex

Return list of MACs found through LLDP on a given ifIndex.

If this proves to be generic enough, it could be promoted to L<pf::Switch>.
In that case, create a generic ifIndexToLldpLocalPort also.

=cut

sub getPhonesLLDPAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my @phones;
    if ( !$self->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch "
                . $self->{_ip}
                . ". getPhonesLLDPAtIfIndex will return empty list." );
        return @phones;
    }
    my $oid_lldpRemPortId  = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemSysCapEnabled = '1.0.8802.1.1.2.1.4.1.1.12';

    if ( !$self->connectRead() ) {
        return @phones;
    }
    $logger->trace(
        "SNMP get_next_request for lldpRemSysCapEnabled: $oid_lldpRemSysCapEnabled");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $oid_lldpRemSysCapEnabled );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid =~ /^$oid_lldpRemSysCapEnabled\.([0-9]+)\.([0-9]+)\.([0-9]+)$/ ) {
            if ( $ifIndex eq $2 ) {
                my $cache_lldpRemTimeMark     = $1;
                my $cache_lldpRemLocalPortNum = $2;
                my $cache_lldpRemIndex        = $3;
                if ( $self->getBitAtPosition($result->{$oid}, $SNMP::LLDP::TELEPHONE) ) {
                    $logger->trace(
                        "SNMP get_request for lldpRemPortId: $oid_lldpRemPortId.$cache_lldpRemTimeMark.$cache_lldpRemLocalPortNum.$cache_lldpRemIndex"
                    );
                    my $MACresult = $self->{_sessionRead}->get_request(
                        -varbindlist => [
                            "$oid_lldpRemPortId.$cache_lldpRemTimeMark.$cache_lldpRemLocalPortNum.$cache_lldpRemIndex"
                        ]
                    );
                    if ($MACresult
                        && ($MACresult->{
                                "$oid_lldpRemPortId.$cache_lldpRemTimeMark.$cache_lldpRemLocalPortNum.$cache_lldpRemIndex"
                            }
                            =~ /([0-9A-Z]{2})\s?([0-9A-Z]{2})\s?([0-9A-Z]{2})\s?([0-9A-Z]{2})\s?([0-9A-Z]{2})\s?([0-9A-Z]{2})$/i
                        )
                        )
                    {
                        push @phones, lc("$1:$2:$3:$4:$5:$6");
                    }
                }
            }
        }
    }
    return @phones;
}

=head2 getBitAtPosition - returns the bit at the position specified

The input must be the untranslated raw result of an snmp get_table

=cut

# TODO move out to a util package


sub getBitAtPosition {
   my ($self, $bitStream, $position) = @_;
   #Expect the hex stream
   if ($bitStream =~ /^0x/) {
       $bitStream =~ s/^0x//i;
       my $bin = join('',map { unpack("B4",pack("H",$_)) } (split //, $bitStream));
       return substr($bin, $position - 8, 1);
   } else {
       my $bin = substr(unpack('B*', $bitStream), -8);
       return substr($bin, $position, 1);
   }
}

=head2 getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($self) = @_;
    return (
    );
}

=head2 deauthenticateMacRadius

Method to deauth a wired node with CoA.

=cut

sub deauthenticateMacRadius {
    my ($self, $ifIndex,$mac) = @_;
    my $logger = $self->logger;


    # perform CoA
    $self->radiusDisconnect($mac);
}


=head2 radiusDisconnect

Send a CoA to disconnect a mac

=cut

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = $self->logger;

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS CoA-Request on (".$self->{'_id'}."): RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating");

    my $send_disconnect_to = $self->{'_ip'};
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $self->deauth_source_ip($send_disconnect_to),
        };

        $logger->debug("network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;
        # Standard Attributes

        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
            'NAS-IP-Address' => $send_disconnect_to,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };
        $response = perform_coa($connection_info, $attributes_ref);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS CoA-Request on (".$self->{'_id'}.") : $_");
        $logger->error("Wrong RADIUS secret or unreachable network device (".$self->{'_id'}.") ...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'CoA-ACK');

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request on (".$self->{'_id'}.")."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
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

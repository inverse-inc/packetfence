package pf::Switch::HP::Procurve_2920;

=head1 NAME

pf::Switch::HP::Procurve_2920 - Object oriented module to access SNMP enabled HP Procurve 2920 switches

=head1 SYNOPSIS

The pf::Switch::HP::Procurve_2920 module implements an object
oriented interface to access SNMP enabled HP Procurve 2920 switches.

=head1 BUGS AND LIMITATIONS

VoIP not tested using MAC Authentication/802.1X

=cut

use strict;
use warnings;
use Net::SNMP;
use base ('pf::Switch::HP');

sub description {'HP ProCurve 2920 Series'}

# importing switch constants
use pf::Switch::constants;
use pf::constants::role qw($VOICE_ROLE);
use pf::util;
use pf::config qw(
    $MAC
    $PORT
);
use pf::constants;

# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x   { return $TRUE; }
sub supportsLldp         { return $TRUE; }
sub supportsRadiusVoip   { return $TRUE; }

# inline capabilities
sub inlineCapabilities { return ( $MAC, $PORT ); }

=head2 getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($self) = @_;
    my $logger = $self->logger;
    my $vlanid = sprintf( "%03x\n", $self->getVlanByName($VOICE_ROLE) );
    my $hexvlan = hex( "31000" . $vlanid );
    return ( 'Egress-VLANID' => $hexvlan, );
}

=head2 getPhonesLLDPAtIfIndex

Using SNMP and LLDP we determine if there is VoIP connected on the switch port

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
    my $oid_lldpRemPortId           = '1.0.8802.1.1.2.1.4.1.1.7';
    my $oid_lldpRemChassisIdSubtype = '1.0.8802.1.1.2.1.4.1.1.12';
    if ( !$self->connectRead() ) {
        return @phones;
    }
    $logger->trace(
        "SNMP get_next_request for lldpRemSysDesc: $oid_lldpRemChassisIdSubtype"
    );
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $oid_lldpRemChassisIdSubtype );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid
            =~ /^$oid_lldpRemChassisIdSubtype\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
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
                        && ($MACresult->{"$oid_lldpRemPortId.$cache_lldpRemTimeMark.$cache_lldpRemLocalPortNum.$cache_lldpRemIndex"}
                            =~ /^(?:0x)?([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})(?::..)?$/i
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

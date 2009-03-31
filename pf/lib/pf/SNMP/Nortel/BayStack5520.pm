package pf::SNMP::Nortel::BayStack5520;

=head1 NAME

pf::SNMP::Nortel::BayStack5520 - Object oriented module to access SNMP enabled Nortel BayStack5520 switches

=head1 SYNOPSIS

The pf::SNMP::Nortel::BayStack5520 module implements an object 
oriented interface to access SNMP enabled Nortel::BayStack5520 switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::Nortel');

sub getBoardPortFromIfIndex {
    my ( $this, $ifIndex ) = @_;

    # return (board,port)
    return ( int( $ifIndex / 64 ), ( $ifIndex % 64 ) );
}

sub getIfIndexFromBoardPort {
    my ( $this, $board, $port ) = @_;
    return ( $board * 64 + $port );
}

#called with $authorized set to true, creates a new line to authorize the MAC
#when $authorized is set to false, deletes an existing line

# WARNING !!!!!!!!!!!!!!
# YOU MIGHT GET BURNED !
# USE AT YOUR OWN RISK
#
# UNFORTUNATELY WE HAVE TO HARDCODE THE BRDINDEX TO 1
# FOR AUTHORIZATION TO WORK
# WE HAVE NO IDEA OF THE IMPLICATIONS THIS MIGHT HAVE ON
# A STACKED SETUP, I.E. WE ARE ALMOST SURE THAT YOU
# WILL OTHERIZE THE MAC ON A WRONG PORT
#
# OTHERWISE THIS IS THE SAME FUNCTION AS THE STANDARD NORTEL ONE
sub _authorizeMAC {
    my ( $this, $ifIndex, $MACHexString, $authorize ) = @_;

    #my $OID_s5SbsAuthCfgBrdIndx = '1.3.6.1.4.1.45.1.6.5.3.10.1.1';
    #my $OID_s5SbsAuthCfgPortIndx = '1.3.6.1.4.1.45.1.6.5.3.10.1.2';
    #my $OID_s5SbsAuthCfgMACIndx = '1.3.6.1.4.1.45.1.6.5.3.10.1.3';
    my $OID_s5SbsAuthCfgAccessCtrlType = '1.3.6.1.4.1.45.1.6.5.3.10.1.4';
    my $OID_s5SbsAuthCfgStatus         = '1.3.6.1.4.1.45.1.6.5.3.10.1.5';

    #my $OID_s5SbsAuthCfgSecureList = '1.3.6.1.4.1.45.1.6.5.3.10.1.6';
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't delete an entry from the SecureMacAddrTable"
        );
        return 1;
    }

    my ( $boardIndx, $portIndx ) = $this->getBoardPortFromIfIndex($ifIndex);

    my $cfgStatus = ($authorize) ? 2 : 3;

    #convert MAC into decimal
    my @MACArray = split( /:/, $MACHexString );
    my $MACDecString = '';
    foreach my $hexPiece (@MACArray) {
        if ( $MACDecString ne '' ) {
            $MACDecString .= ".";
        }
        $MACDecString .= hex($hexPiece);
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $result;

    if ($authorize) {

        #WARNING
        #HERE'S THE UGLY HACK
        $boardIndx = 1;
        $logger->warn("ugly hack here: setting boardIndx to 1");

        #END OF THE UGLY HACK
        $logger->trace(
            "SNMP set_request for s5SbsAuthCfgAccessCtrlType: $OID_s5SbsAuthCfgAccessCtrlType"
        );
        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_s5SbsAuthCfgAccessCtrlType.$boardIndx.$portIndx.$MACDecString",
                Net::SNMP::INTEGER,
                1,
                "$OID_s5SbsAuthCfgStatus.$boardIndx.$portIndx.$MACDecString",
                Net::SNMP::INTEGER,
                $cfgStatus
            ]
        );
    } else {
        $logger->trace(
            "SNMP set_request for s5SbsAuthCfgStatus: $OID_s5SbsAuthCfgStatus"
        );
        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_s5SbsAuthCfgStatus.$boardIndx.$portIndx.$MACDecString",
                Net::SNMP::INTEGER,
                $cfgStatus
            ]
        );
    }

    return ( defined($result) );
}

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2008 Inverse inc.

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

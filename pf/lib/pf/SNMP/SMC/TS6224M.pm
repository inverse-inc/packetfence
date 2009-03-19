#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
#  Modified for supporting SMC LAN SWITCHES
# Model TigerSwitch 6224M
#
# Mr. Chinasee BOONYATANG 	 	[chinasee.b@psu.ac.th]
#  Prince of Songkla University , Thailand
#  http://netserv.cc.psu.ac.th
#  2009-01-23
#
#

package pf::SNMP::SMC::TS6224M;

=head1 NAME

pf::SNMP::SMC::TS6224M - Object oriented module to access SNMP 
enabled SMC Switch - TigerStack 6224M switches

=head1 SYNOPSIS

The pf::SNMP::SMC::TS6224M module implements an object 
oriented interface to access SNMP enabled 
SMC Switch - TigerStack 6224M switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::SMC');

sub getDot1dBasePortForThisIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return 0;
    }

    #get Physical port amount
    my $OID_dot1dBaseNumPort = '1.3.6.1.2.1.17.1.2.0';    #from BRIDGE-MIB

    $logger->trace(
        "SNMP get_request for dot1dBaseNumPort : $OID_dot1dBaseNumPort");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_dot1dBaseNumPort"] );

    if ( !( exists( $result->{"$OID_dot1dBaseNumPort"} ) ) ) {
        return 0;
    }

    my $dot1dBaseNumPort = $result->{$OID_dot1dBaseNumPort};

    my $dot1dBasePort = 0;

    if ( ( $ifIndex > 0 ) && ( $ifIndex <= $dot1dBaseNumPort ) ) {
        $dot1dBasePort = $ifIndex;
    }

    return $dot1dBasePort;
}

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

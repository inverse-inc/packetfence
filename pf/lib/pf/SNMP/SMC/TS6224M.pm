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

=head1 AUTHOR

Mr. Chinasee BOONYATANG <chinasee.b@psu.ac.th>

  Prince of Songkla University, Thailand
  http://netserv.cc.psu.ac.th

=head1 COPYRIGHT

Copyright (C) 2006-2008 Inverse groupe conseil

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

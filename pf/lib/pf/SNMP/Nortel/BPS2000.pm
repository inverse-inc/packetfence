#
# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::Nortel::BPS2000;

=head1 NAME

pf::SNMP::Nortel::BPS2000 - Object oriented module to access SNMP enabled Nortel BPS2000 switches

=head1 SYNOPSIS

The pf::SNMP::Nortel::BPS2000 module implements an object 
oriented interface to access SNMP enabled Nortel::BPS2000 switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::Nortel');

sub getPhonesLLDPAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @phones;
    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch "
                . $this->{_ip}
                . ". getPhonesLLDPAtIfIndex will return empty list." );
        return @phones;
    }
    $logger->debug("LLDP is not available on BPS2000");
    return @phones;
}

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

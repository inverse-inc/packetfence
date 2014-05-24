package pf::Switch::Dlink::DES_3526;

=head1 NAME

pf::Switch::Dlink::DES_3526 - Object oriented module to access SNMP enabled Dlink DES 3526 switches

=head1 SYNOPSIS

The pf::Switch::Dlink::DES_3526 module implements an object oriented interface
to access SNMP enabled Dlink DES 3526 switches.

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::Switch::Dlink');

sub description { 'D-Link DES 3526' }

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my @fields = split '\|', $trapString;

    my ( $ifIndex, $op, $mac );
    for my $field (@fields) { 
        ( $ifIndex, $op ) = $field =~ /^.1.3.6.1.4.1.171.11.64.1.2.14.1.1.1.(\d+) = INTEGER: (\d+)/;
        ( $mac ) =  $field =~ /^.1.3.6.1.4.1.171.11.64.1.2.15.2.1 = Hex-STRING: ($SNMP::MAC_ADDRESS_FORMAT)/;
    }

    $mac = lc $mac;
    $mac =~ s/ /:/g;

    
    $trapHashRef->{'trapType'} = 'mac';
    if ( $op == 1 ) {
        $trapHashRef->{'trapOperation'} = 'learnt';
    } elsif ( $op == 2 ) {
        $trapHashRef->{'trapOperation'} = 'removed';
    } else {
        $trapHashRef->{'trapOperation'} = 'unknown';
        $logger->debug("trap currently not handled");
    }
    $trapHashRef->{'trapIfIndex'} = $ifIndex;
    # is this really necessary?
    #$trapHashRef->{'trapVlan'} = $this->getVlan( $ifindex );

    return $trapHashRef;
}

=head1 AUTHOR

Treker Chen <treker.chen@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2008 Treker Chen

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

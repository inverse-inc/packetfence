package pf::Switch::Dlink::DES_3526;

=head1 NAME

pf::Switch::Dlink::DES_3526 - Object oriented module to access SNMP enabled Dlink DES 3526 switches

=head1 SYNOPSIS

The pf::Switch::Dlink::DES_3526 module implements an object oriented interface
to access SNMP enabled Dlink DES 3526 switches.

Tested on Firmware: Build 5.01.B65.
No port security support, no RADIUS.

=cut

use strict;
use warnings;
use Net::SNMP;
use base ('pf::Switch::Dlink');

sub description {'D-Link DES 3526'}

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    my @fields = split '\|', $trapString;

    # REGULAR EXPRESSIONS
    # match 00 24 BE B1 F6 31
    my $mac_re = qr/
        (                               # capture: $1 is the MAC
        (?: [[:xdigit:]] {2}\s) {5}     # 5 pairs of xdigits followed by one space
        [[:xdigit:]]{2}                 # a final pair of x digits
        )
    /x;

    # match .1.3.6.1.4.1.171.11.64.1.2.15.1 = Hex-STRING: 01 00 1C C0 91 72 B9 00 01 00 1A 00  END VARIABLEBINDINGS
    my $mac_notification_re = qr/
        ^ \.1\.3\.6\.1\.4\.1\.171\.11\.64\.[12]\.2\.15\.1
        \s=\s
        Hex-STRING:\s
        ([[:xdigit:]]{2}) \s                        # Capture: $1 is op status code
        $mac_re \s                                  # Capture: $2 is the MAC
        (?:[[:xdigit:]]{2} \s [[:xdigit:]]{2})\s    # non capturing
        ([[:xdigit:]]{2} \s [[:xdigit:]]{2})        # Capture: $3 is the ifIndex
    /x ;

    my ( $ifIndex, $mac, $op );
    PARSETRAP:
    for my $field (@fields) {

        if ( !defined $mac && $field =~ $mac_notification_re ) {
            $trapHashRef->{'trapType'} = 'mac';

            ( $op, $mac, $ifIndex ) = ( $1, $2, $3 );
            if ( $op == 1 ) {
                $trapHashRef->{'trapOperation'} = 'learnt';
            } elsif ( $op == 2 ) {
                $trapHashRef->{'trapOperation'} = 'removed';
            } else {
                $trapHashRef->{'trapOperation'} = 'unknown';
            }

            $mac = lc $mac;
            $mac =~ s/ /:/g;
            $trapHashRef->{'trapMac'}     = $mac;

            $ifIndex =~ s/ //g;
            $ifIndex = hex $ifIndex;
            $trapHashRef->{'trapIfIndex'} = $ifIndex;

            $trapHashRef->{'trapVlan'} = $self->getVlan( $ifIndex );
            next PARSETRAP;
        }

    }

    unless ( $ifIndex && $op ) {
        $trapHashRef->{'trapType'} = 'unknown';
        $logger->debug("trap currently not handled");
    }

    return $trapHashRef;
}

=head1 AUTHOR

Treker Chen <treker.chen@gmail.com> for the original implementation.
Inverse inc. <info@inverse.ca> for the updated version.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

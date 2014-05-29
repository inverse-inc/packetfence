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

sub description {'D-Link DES 3526'}

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my @fields = split '\|', $trapString;

    # REGULAR EXPRESSIONS
    # match 00 24 BE B1 F6 31 
    my $mac_re = qr/
        (                               # capture: $1 is the MAC
        (?: [[:xdigit:]] {2}\s) {5}     # 5 pairs of xdigits followed by one space
        [[:xdigit:]]{2}                 # a final pair of x digits 
        )
    /x;

    # match .1.3.6.1.4.1.171.11.64.1.2.14.1.1.1.1 = INTEGER: 1
    my $portsec_violation_re = qr/
        ^  .1.3.6.1.4.1.171.11.64.1.2.14.1.1.1\.(\d+) # capture: ifIndex is $1
    /x;

    # match .1.3.6.1.4.1.171.11.64.1.2.15.2.1 = Hex-STRING: 00 24 BE B1 F6 31  END VARIABLEBINDINGS
    my $portsec_mac_re = qr/
        ^  .1.3.6.1.4.1.171.11.64.1.2.15.2.1
        \s=\s 
        Hex-STRING:\s $mac_re           # capture: $1 is the MAC
    /x;

    # match .1.3.6.1.2.1.2.2.1.7.2 = INTEGER: up(1)
    my $linkstatus_re = qr/
        ^  .1.3.6.1.2.1.2.2.1.7\.(\d+)  # capture: $1 is the ifIndex
        \s=\s                           #   = 
        INTEGER:\s                      # INTEGER:  
        [^(]+                           # anything but a (
        \(                              # a litteral (
            (\d)                        # capture: $2 is the op status code
        \)                              # a litteral )
    /x;

    my ( $ifIndex, $mac, $op );
    PARSETRAP:
    for my $field (@fields) {

        # portsec violation
        if ( !defined $ifIndex && $field =~ $portsec_violation_re ) {
            $ifIndex                        = $1;
            $op                             = 'learnt';
            $trapHashRef->{'trapIfIndex'}   = $ifIndex;
            $trapHashRef->{'trapOperation'} = $op;
            next PARSETRAP;
        }

        if ( !defined $mac && $field =~ $portsec_mac_re ) {
            $mac = $1;
            $mac = lc $mac;
            $mac =~ s/ /:/g;
            $trapHashRef->{'trapType'} = 'mac';
            $trapHashRef->{'trapMac'}  = $mac;
            next PARSETRAP;
        }

        # linkup
        if ( !defined $ifIndex && $field =~ $linkstatus_re ) {
            ( $ifIndex, $op ) = ( $1, $2 );
            $trapHashRef->{'trapIfIndex'} = $ifIndex;
            $trapHashRef->{'trapOperation'} = ( ( $op == 1 ) ? 'up' : 'unknown' );
        }
    }

    unless ( $ifIndex && $op ) {
        $trapHashRef->{'trapOperation'} = 'unknown';
        $logger->debug("trap currently not handled");
    }

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

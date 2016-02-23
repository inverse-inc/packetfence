package pf::detect::parser::security_onion;

=head1 NAME

pf::detect::parser::security_onion

=cut

=head1 DESCRIPTION

pf::detect::parser::security_onion

Class to parse syslog from a Security onion appliance

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::detect::parser);

sub parse {
    my ($self,$line) = @_;

    # Alert line example
    # Oct 28 13:37:42 poulichefencer sguil_alert: 13:37:42 pid(3403)  Alert Received: 0 2 misc-attack securityonion1-eth1 {2015-10-28 13:37:42} 3 88707 {ET TOR Known Tor Relay/Router (Not Exit) Node Traffic group 11} SRC.IP.AD.DR DST.IP.AD.DR 17 123 123 1 2522020 2376 7946 7946
    # Split the line on the Curly Brace { }
    my @split1 = split(m/[{}](?![^{}!()]*\))/, $line);
    my @split2 = split(" ", $split1[4]);

    my $data = {
        date    => $split1[1],
        descr   => $split1[3],
        srcip   => $split2[0],
        dstip   => $split2[1],
        sid     => $split2[6],
    };

    return { date => $data->{date}, srcip => $data->{srcip}, dstip => $data->{dstip}, events => { detect => $data->{sid}, suricata_event => $data->{descr} } };
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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


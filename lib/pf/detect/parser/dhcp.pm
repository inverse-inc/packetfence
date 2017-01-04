package pf::detect::parser::dhcp;

=head1 NAME

pf::detect::parser::dhcp

=cut

=head1 DESCRIPTION

pfdetect parser class for DHCP syslog (supports at least infoblox and ISC DHCP)

=cut

use strict;
use warnings;

use Moo;

use pf::api::queue;
use pf::iplog;
use pf::log;

extends qw(pf::detect::parser);

sub parse {
    my ( $self, $line ) = @_;
    my $logger = pf::log::get_logger();

    my $data = $self->_parse($line);

    if(defined($data->{type}) && $data->{type} eq "DHCPACK") {
        my $apiclient = pf::api::queue->new;
        $apiclient->notify('update_iplog', ( 'mac' => $data->{mac}, ip => $data->{ip} ));
    }

    return 0;   # Returning 0 to pfdetect indicates "job's done"
}

sub _parse { 
    my ( $self, $line ) = @_;
    my $logger = pf::log::get_logger();
    my $data = {};

    my $type_match = "(DHCPDISCOVER|DHCPOFFER|DHCPREQUEST|DHCPACK|DHCPRELEASE|DHCPINFORM|DHCPEXPIRE)";
    my $ip_match = "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)";
    my $mac_match = "([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})";
    # DHCPACK on 10.33.17.82 to 00:11:22:33:44:55
    # DHCPACK to 10.17.97.134 (00:11:22:33:44:55)
    if($line =~ /$type_match on $ip_match to $mac_match/) {
        $data->{type} = $1;
        $data->{ip} = $2;
        $data->{mac} = $3;
    }
    elsif($line =~ /$type_match to $ip_match \($mac_match\)/) {
        $data->{type} = $1;
        $data->{ip} = $2;
        $data->{mac} = $3;
    }
    else {
        get_logger->debug("Unknown line : $line");
    }

    return $data;
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

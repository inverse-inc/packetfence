package pf::rawip;

=head1 NAME

pf::rawip - module for ARP spoofing.

=head1 WARNING

This code is deprecated and will be removed in an upcoming PacketFence release

=head1 DESCRIPTION

pf::rawip contains the functions used for ARP spoofing when PacketFence is configured in ARP mode.

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::Frame::Layer::ETH qw(:consts);
use Net::Frame::Layer::ARP qw(:consts);
use Net::Frame::Simple;
use Net::Write::Layer2;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(trapmac arpmac freemac);
}
use pf::config;
use pf::util;
use pf::iplog qw(mac2allips ip2mac mac2ip);

sub trapmac {
    my ($mac)  = @_;
    my $logger = Log::Log4perl::get_logger('pf::rawip');
    my $all_ok = 1;
    foreach my $ip ( mac2allips($mac) ) {
        #FIXME deprecated during interface.gateway cleanup
        my $gip  = ip2gateway($ip);
        my $gmac = getlocalmac( ip2device($ip) );
        # got rid of trappable_ip below during the interface.gateway cleanup
        #if ( whitelisted_mac($mac) || !trappable_mac($mac) || !trappable_ip($ip) ) {
        if ( whitelisted_mac($mac) || !trappable_mac($mac) ) {
            $all_ok = 0;
        } else {
            $logger->info(
                "trapping $mac (ip: $ip, gwip: $gip, gwmac: $gmac)");

            #arpmac($gmac,$gip,$mac,$ip,0,2);
            arpmac( $gmac, $gip, $mac, $ip, 0, 1 );
        }
    }
    return ($all_ok);
}

sub freemac {
    my $destmac = shift;
    my $logger  = Log::Log4perl::get_logger('pf::rawip');
    foreach my $destip ( mac2allips($destmac) ) {
        my $destgateip  = ip2gateway($destip);
        my $destgatemac = ip2mac($destgateip);
        if ( $destgatemac && $destgateip && $destip ) {
            $logger->info(
                "releasing $destmac (ip: $destip, gwip: $destgateip, gwmac: $destgatemac)"
            );

            #&arpmac($destgatemac,$destgateip,$destmac,$destip,0,2);
            &arpmac( $destgatemac, $destgateip, $destmac, $destip, 0, 1 );
        }
    }
    return (0);
}

sub arpmac {
    my ( $mymac, $myip, $destmac, $destip, $delay, $type ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::rawip');

    return 0 if ( !$mymac || !$myip || !$destip || !$destmac );

    my $eth = ip2device($myip);
    if ( $eth =~ /:/ ) {
        $eth =~ s/(\S+):\S+/$1/;
    }

    my $ethLayer = Net::Frame::Layer::ETH->new(
        type => NF_ETH_TYPE_ARP,
        src  => $mymac,
        dst  => $destmac,
    );
    my $arpLayer = Net::Frame::Layer::ARP->new(
        opCode =>
            ( $type == 1 ? NF_ARP_OPCODE_REQUEST : NF_ARP_OPCODE_REPLY ),
        srcIp => $myip,
        dstIp => $destip,
        src   => $mymac,
        dst   => $destmac,
    );
    my $pktToSend
        = Net::Frame::Simple->new( layers => [ $ethLayer, $arpLayer ], );
    $logger->debug(
        "ARP type=$type src $eth $mymac $myip -> dst $destmac content: [$mymac,$myip,$destmac,$destip]"
    );

    my $oWrite = Net::Write::Layer2->new( dev => $eth );
    $oWrite->open;
    $oWrite->send( $pktToSend->raw );
    $oWrite->close;
}

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

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

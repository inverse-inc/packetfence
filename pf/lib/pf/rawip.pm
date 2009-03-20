package pf::rawip;

=head1 NAME

pf::rawip

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
        my $gip  = ip2gateway($ip);
        my $gmac = getlocalmac( ip2device($ip) );
        if ( !trappable_mac($mac) || !trappable_ip($ip) ) {
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
    if ( !isenabled( $Config{'trapping'}{'testing'} ) ) {
        my $oWrite = Net::Write::Layer2->new( dev => $eth );
        $oWrite->open;
        $oWrite->send( $pktToSend->raw );
        $oWrite->close;
    } else {
        $logger->warn("not sending frame, testing mode enabled");
    }
}

=head1 COPYRIGHT

Copyright 2005 David LaPorte <david@davidlaporte.org>

Copyright 2005 Kevin Amorin <kev@amorin.org>

See the enclosed file COPYING for license information (GPL).
If you did not receive this file, see
F<http://www.fsf.org/licensing/licenses/gpl.html>.

=cut

1;

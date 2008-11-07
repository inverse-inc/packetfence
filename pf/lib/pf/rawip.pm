#
# Copyright 2005 David LaPorte <david@davidlaporte.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::rawip;

use strict;
use warnings;
use Net::RawIP;
use Log::Log4perl;


BEGIN {
  use Exporter ();
  our (@ISA, @EXPORT);
  @ISA    = qw(Exporter);
  @EXPORT = qw(trapmac arpmac freemac);
}
use pf::config;
use pf::util;
use pf::iplog qw(mac2allips ip2mac mac2ip);

sub trapmac {
  my ($mac) = @_;
  my $logger = Log::Log4perl::get_logger('pf::rawip');
  my $all_ok = 1;
  foreach my $ip (mac2allips($mac)) {
    my $gip = ip2gateway($ip);
    my $gmac = getlocalmac(ip2device($ip));
    if (!trappable_mac($mac) || !trappable_ip($ip)) {
      $all_ok = 0;
    } else {
      $logger->info("trapping $mac (ip: $ip, gwip: $gip, gwmac: $gmac)");
      #arpmac($gmac,$gip,$mac,$ip,0,2);
      arpmac($gmac,$gip,$mac,$ip,0,1);
    }
  }
  return($all_ok);
}

sub freemac {
  my $destmac = shift;
  my $logger = Log::Log4perl::get_logger('pf::rawip');
  foreach my $destip (mac2allips($destmac)) {
    my $destgateip = ip2gateway($destip);
    my $destgatemac = ip2mac($destgateip);
    if ($destgatemac && $destgateip && $destip) {
      $logger->info("releasing $destmac (ip: $destip, gwip: $destgateip, gwmac: $destgatemac)");
      #&arpmac($destgatemac,$destgateip,$destmac,$destip,0,2);
      &arpmac($destgatemac,$destgateip,$destmac,$destip,0,1);
    }
  }
  return(0);
}


sub arpmac {
  my ($mymac,$myip,$destmac,$destip,$delay,$type) = @_;
  my $logger = Log::Log4perl::get_logger('pf::rawip');

  return 0 if (!$mymac || !$myip || !$destip || !$destmac);

  my $a = new Net::RawIP;

  my $eth=ip2device($myip);
  if ($eth=~/:/){
    $eth=~s/(\S+):\S+/$1/;
  }

  # set the src eth device to that interface
  $a->ethnew($eth);
  $a->ethset(source => $mymac, dest => $destmac);
 
  my @destmac=split(/:/,$destmac);
  foreach my $index (0 .. 5) {$destmac[$index]=hex("00$destmac[$index]");}
  my @mymac=split(/:/,$mymac);
  foreach my $index (0 .. 5) {$mymac[$index]=hex("00$mymac[$index]");}

  my $sip=unpack("N",pack("C4", split/\./, $myip));
  my $dip=unpack("N",pack("C4", split/\./, $destip));

  my $padding = "KevinAmorinDaveLaPorte";

  $logger->debug("ARP type=$type src $eth $mymac $myip -> dst $destmac content: [$mymac,$myip,$destmac,$destip]");
  my $arp=pack("nnnCCnCCCCCCNCCCCCCN",2054,1,2048,6,4,$type,@mymac,$sip,@destmac,$dip).$padding;

  # don't send the frame in testing!!
  if (!isenabled($Config{'trapping'}{'testing'})) {
    $a->send_eth_frame($arp,$delay,1);
  }else{
    $logger->warn("not sending frame, testing mode enabled");
  } 
}

1

# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

use Log::Log4perl;
use Net::Netmask;
use threads;
use threads::shared;
use Net::Ping;

# don't act on configured uplinks
sub custom_doWeActOnThisTrap {
    my ($switch, $ifIndex, $trapType) = @_;
    my $logger = Log::Log4perl->get_logger();
    Log::Log4perl::MDC->put('tid', threads->self->tid());

    my $weActOnThisTrap = 0;

    if ($switch->getIfType($ifIndex) == 6) {
        my @upLinks = $switch->getUpLinks();
        if ($upLinks[0] == -1) {
            $logger->info("can not determine uplinks for the switch -> do nothing");
        } else {
            if (grep(/^$ifIndex$/, @upLinks) == 0) {
                $weActOnThisTrap = 1;
            } else {
                $logger->info("trap received at " . $switch->{_ip} . " ifindex $ifIndex which is uplink and we don't manage uplinks");
            }
        }
    } else {
        $logger->info("trap was not received on ethernetCsmacd port");
    }
    return $weActOnThisTrap;
}

# don't act on dynamic ports and unmanaged vlans
#sub custom_doWeActOnThisTrap {
#    my ($switch, $ifIndex, $trapType) = @_;
#    my $logger = Log::Log4perl->get_logger();
#    Log::Log4perl::MDC->put('tid', threads->self->tid());
#
#    my $weActOnThisTrap = 0;
#
#    if ($switch->getIfType($ifIndex) == 6) {
#        if ($switch->getVmVlanType($ifIndex) == 1) {
#            my $port_vlan = $switch->getVlan($ifIndex);
#            if ( grep(/^$port_vlan$/, @{$switch->{_vlans}}) != 0 ) {  # managed vlan ?
#                $weActOnThisTrap = 1;
#            } else {
#                $logger->debug("trap received at " . $switch->{_ip} . " ifindex $ifIndex for vlan $port_vlan, we do not manage this vlan");
#            }
#        } else {
#            $logger->debug("trap received at " . $switch->{_ip} . " ifindex $ifIndex which is dynamic, we do not manage dynamic ports");
#        }
#    } else {
#        $logger->info("trap was not received on ethernetCsmacd port");
#    }
#    return $weActOnThisTrap;
#}


sub custom_getCorrectVlan {
    #$switch_ip is the ip of the switch
    #$ifIndex is the ifIndex of the computer connected to
    #$mac is the mac connected
    #$status is the node's status in the database
    #$vlan is the vlan set for this node in the database
    #$pid is the owner of this node in the database
    my ($switch_ip, $ifIndex, $mac, $status, $vlan, $pid) = @_;
    my $logger = Log::Log4perl->get_logger();
    Log::Log4perl::MDC->put('tid', threads->self->tid());

#   if ($vlan eq '') {
#        $logger->info("MAC: $mac is registered but VLAN is not set; setting into registration VLAN");
#        $vlan = $switch->{_registrationVlan};
#    }
    return $vlan;
}

sub custom_isClientAlive {
    my ($mac, $switch_ip, $ifIndex, $currentVlan, $isolationVlan, $mysql_connection) = @_;
    my $logger = Log::Log4perl->get_logger();
    Log::Log4perl::MDC->put('tid', threads->self->tid());

    my $ip;
    my $returnValue = 0;
    my $src_ip = undef;

    # find ip for oldMac
    my @ipLog = $mysql_connection->selectrow_array("SELECT ip FROM iplog WHERE mac='$mac' AND start_time <> 0 AND (end_time = 0 OR end_time > now())");
    if (@ipLog) {
        $ip = $ipLog[0];
        $logger->debug("mac $mac has IP $ip");
    } else {
        $logger->error("coudn't find ip for $mac in table iplog.");
        return 0;
    }

    my @lines = `/sbin/ip address show`;
    my $lineNb = 0;
    while (($lineNb < scalar(@lines)) && (! defined($src_ip))) {
        my $line = $lines[$lineNb];
        if ($line =~ /inet ([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\/([0-9]+)/) {
            my $tmp_src_ip = $1;
            my $tmp_src_bits = $2;
            my $block = new Net::Netmask("$tmp_src_ip/$tmp_src_bits");
            if ($block->match($ip)) {
                $src_ip = $tmp_src_ip;
                $logger->debug("found $ip in Network $tmp_src_ip/$tmp_src_bits");
            }
        }
        $lineNb++;
    }

    my $count = 1;
    while (($returnValue != 1) && ($count < 6)) {
        my $ping = Net::Ping->new();
        if (defined($src_ip)) {
            $ping->bind($src_ip);
            $logger->debug("binding ping src IP to $src_ip for icmp ping");
        }

        if ($ping->ping($ip,2)) {
            $returnValue = 1;
            $logger->debug("$ip is alive (ping).");
        }
        $ping->close();
        $count++;
    }

    return $returnValue;
}


sub custom_getNodeInfo {
    my ($switch_ip, $switch_port, $mac, $vlan, $isPhone, $mysql_connection) = @_;
    my $new = {};
    $new->{'switch'} = $switch_ip;
    $new->{'port'} = $switch_port;
    if ($isPhone) {
        $new->{'dhcp_fingerprint'} = '1,3,6,15,42,66,150';
    }

    return $new;
}

sub custom_getNodeInfoForAutoReg {
    my ($switch_ip, $switch_port, $mac, $vlan, $isPhone, $mysql_connection) = @_;
    my $new;
    $new->{'pid'} = 'PF';
    $new->{'user_agent'} = 'AUTO-REGISTERED';
    $new->{'status'} = 'reg';
    $new->{'vlan'} = 1;
    if ($isPhone) {
        $new->{'dhcp_fingerprint'} = '1,3,6,15,42,66,150';
    }
    return $new;
}

sub custom_shouldAutoRegister {
    my ($mac, $isPhone) = @_;
    return $isPhone;
}

1;


# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

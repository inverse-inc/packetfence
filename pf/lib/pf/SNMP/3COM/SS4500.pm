#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
# Modified for supporting 3COM  Hauwei switches 
# Model SuperStack 3 Switch - 4500 
#  
# Mr. Chinasee BOONYATANG <chinasee.b@psu.ac.th>
# Mr.Ponpitak SANTIPAPTAWON	<ponpitak.s@psu.ac.th>
# Prince of Songkla University , Thailand 
# http://netserv.cc.psu.ac.th
# 2008-11-21
#
# *** SETVLAN NOT WORK WITH DEFAULT VLAN ID 1 ***
#

package pf::SNMP::3COM::SS4500;

=head1 NAME

pf::SNMP::3COM::SS4500 - Object oriented module to access SNMP enabled 3COM Huawei SuperStack 3 Switch - 4500 switches


=head1 SYNOPSIS

The pf::SNMP::3COM::SS4500 module implements an object 
oriented interface to access SNMP enabled 
3COM Huawei SuperStack 3 Switch - 4500 switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::3COM');

sub getVersion {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
	
	my $OID_hwLswSysVersion = '1.3.6.1.4.1.43.45.1.2.23.1.18.1.4.0'; #from A3COM-HUAWEI-DEVICE-MIB
    if (! $this->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_request for hwLswSysVersion: $OID_hwLswSysVersion");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => ["$OID_hwLswSysVersion"]
    );

	if ((exists($result->{"$OID_hwLswSysVersion"})) && ($result->{"$OID_hwLswSysVersion"} ne 'noSuchInstance')) {
		return $result->{"$OID_hwLswSysVersion"};
	} else {
		return 0;
	}
}

sub parseTrap {
    my ($this, $trapString) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger(ref($this));
	
	# link status trap varbind oid = 1.3.6.1.2.1.2.2.1.1  from RFC-1213-MIB
    if ($trapString =~ /BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = /) {
        $trapHashRef->{'trapType'} = (($1 == 2) ? "down" : "up");									
        $trapHashRef->{'trapIfIndex'} = $2;
    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub isDefinedVlan {
    my ($this, $vlan) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    my $OID_hwdot1qVlanIndex = '1.3.6.1.4.1.43.45.1.2.23.1.2.1.1.1.1'; #from A3COM-HUAWEI-LswVLAN-MIB
    if (! $this->connectRead()) {
        return 0;
    }

    $logger->trace("SNMP get_request for hwdot1qVlanIndex: $OID_hwdot1qVlanIndex.$vlan");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => ["$OID_hwdot1qVlanIndex.$vlan"]
    );

    return (defined($result) && exists($result->{"$OID_hwdot1qVlanIndex.$vlan"}) && ($result->{"$OID_hwdot1qVlanIndex.$vlan"} ne 'noSuchInstance'));
}


sub getDot1dBasePortForThisIfIndex { 
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
	my $OID_hwifXXBasePortIndex = '1.3.6.1.4.1.43.45.1.2.23.1.1.1.1.10.'.$ifIndex; #from A3COM-HUAWEI-LswINF-MIB
	
	if (! $this->connectRead()) {
        return 0;
    }
    
    $logger->trace("SNMP get_request for hwifXXBasePortIndex: $OID_hwifXXBasePortIndex");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => ["$OID_hwifXXBasePortIndex"]
    );
	
    if ((exists($result->{"$OID_hwifXXBasePortIndex"})) && ($result->{"$OID_hwifXXBasePortIndex"} ne 'noSuchInstance')) {
        return $result->{"$OID_hwifXXBasePortIndex"}; #return port number (Integer)
    } else {
        return 0; #no port return
    }
}

sub getVlan {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1'; # Q-BRIDGE-MIB
    if (! $this->connectRead()) {
        return 0;
    }
    
    $logger->trace("SNMP get_request for dot1qPvid: $OID_dot1qPvid.$ifIndex");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => ["$OID_dot1qPvid.$ifIndex"]
    );
	
    return $result->{"$OID_dot1qPvid.$ifIndex"};
}

sub _setVlan {
    my ($this,$ifIndex,$newVlan,$oldVlan,$switch_locker_ref) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    
	if (! $this->connectRead()) {
        return 0;
    }
   
    my $dot1dBasePort = $this->getDot1dBasePortForThisIfIndex($ifIndex); 		#physical port number
	my $OID_hwdot1qVlanName = '1.3.6.1.4.1.43.45.1.2.23.1.2.1.1.1.2'; 			# VLAN Name from A3COM-HUAWEI-LswVLAN-MIB
	my $OID_hwdot1qVlanPortList = '1.3.6.1.4.1.43.45.1.2.23.1.2.1.1.1.3'; 		#VLAN Port List from A3COM-HUAWEI-LswVLAN-MIB
	
	$this->{_sessionRead}->translate(0);
	$logger->trace("SNMP get_request for hwdot1qVlanName: $OID_hwdot1qVlanName.$newVlan");
	$logger->trace("SNMP get_request for hwdot1qVlanPortsList: $OID_hwdot1qVlanPortList.$newVlan");
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => ["$OID_hwdot1qVlanName.$newVlan","$OID_hwdot1qVlanPortList.$newVlan"]
    );
	
	if (!((exists($result->{"$OID_hwdot1qVlanName.$newVlan"})) && (exists($result->{"$OID_hwdot1qVlanPortList.$newVlan"})))){
		return 0;
	}
	
	my $vlanName = $result->{"$OID_hwdot1qVlanName.$newVlan"}; 						# String of VLAN Name (ex. VLAN 0001, VLAN 0100 etc.)
	my $vlanPortList = unpack "H*",$result->{"$OID_hwdot1qVlanPortList.$newVlan"}; 	# String of Hexadecimal
	
	my $byteNum = int(($dot1dBasePort-1)/8);
	my $byteVal = substr($vlanPortList,$byteNum*2,2);
	
	$byteVal = hex $byteVal; 
	$byteVal += 256; 															# add bit "1" at 9th bit

	my $vlanPortListPrev = substr($vlanPortList,0,$byteNum*2);					# devide port list into 2 of strings
	my $vlanPortListPost = substr($vlanPortList,$byteNum*2+2);

	my $digitNum = $dot1dBasePort-(8*$byteNum)-1;
	my $digitVal = 2**$digitNum;
	
	$digitVal += 256; 															# add bit '1' at 9th bit
	
	$byteVal = $byteVal | $digitVal;											# OR opearation for remain other port's member state except target port
	$byteVal -= 256;															# remove 9th bit 
	$byteVal = sprintf("%.2x",$byteVal); 										# convert to hex string

	$vlanPortList = $vlanPortListPrev.$byteVal.$vlanPortListPost;				# recompose PortList
	
	my $vlanPortListHex = pack "H*", $vlanPortList;								# Reform Octet String
	
	if (! $this->connectWrite()) {
        return 0;
    }
	
    $logger->trace("SNMP set_request for Pvid for new VLAN");
    $result = $this->{_sessionWrite}->set_request(								#SNMP SET
		-varbindlist => ["$OID_hwdot1qVlanName.$newVlan",Net::SNMP::OCTET_STRING,$vlanName,
						 "$OID_hwdot1qVlanPortList.$newVlan",Net::SNMP::OCTET_STRING,$vlanPortListHex]
	);
	
    if (! defined ($result)) {
        $logger->error("error setting Pvid: " . $this->{_sessionWrite}->error);
    }
	
    return (defined($result));
}
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

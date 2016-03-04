package pf::parking;

use strict;
use warnings;

use pf::log;
use pf::OMAPI;
use pf::violation;
use pf::constants::parking qw($PARKING_VID $PARKING_GROUP_NAME);
use pf::constants;
use pf::config;
use pf::util;

sub trigger_parking {
    my ($mac) = @_;
    if(violation_count_open_vid($mac, $PARKING_VID) || violation_trigger( { mac => $mac, tid => 'parking_detected', type => 'INTERNAL' } )){
        park($mac);
    }
}

sub park {
    my ($mac) = @_;
    get_logger->debug("Setting client in parking");
    if(isenabled($Config{parking}{place_in_dhcp_parking_group})){
        my $omapi = pf::OMAPI->get_client();
        $omapi->create_host($mac, {group => $PARKING_GROUP_NAME});
    }
}

sub unpark {
    my ($mac) = @_;
    my $omapi = pf::OMAPI->get_client();
    if(violation_close($mac, $PARKING_VID) != -1){
        get_logger->info("Unparking device $mac");
        $omapi->delete_host($mac);
        return $TRUE;
    }
    else {
        get_logger->info("Device $mac cannot be unparked since the violation cannot be closed");
        return $FALSE;
    }
}

1;

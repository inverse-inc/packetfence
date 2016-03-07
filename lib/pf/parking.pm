package pf::parking;

use strict;
use warnings;

use pf::log;
use pf::OMAPI;
use pf::violation;
use pf::constants::parking qw($PARKING_VID $PARKING_DHCP_GROUP_NAME $PARKING_IPSET_NAME);
use pf::constants;
use pf::config;
use pf::util;

sub trigger_parking {
    my ($mac,$ip) = @_;
    if(violation_count_open_vid($mac, $PARKING_VID) || violation_trigger( { mac => $mac, tid => 'parking_detected', type => 'INTERNAL' } )){
        park($mac,$ip);
    }
}

sub park {
    my ($mac,$ip) = @_;
    get_logger->debug("Setting client in parking");
    if(isenabled($Config{parking}{place_in_dhcp_parking_group})){
        my $omapi = pf::OMAPI->get_client();
        $omapi->create_host($mac, {group => $PARKING_DHCP_GROUP_NAME});
    }
    if(isenabled($Config{parking}{show_parking_portal})){
        my $cmd = "LANG=C sudo ipset add $PARKING_IPSET_NAME $ip 2>&1";
        get_logger->debug("Adding device to parking ipset using $cmd");
        my $_EXIT_CODE_EXISTS = "1";
        my @lines = pf_run($cmd, accepted_exit_status => [$_EXIT_CODE_EXISTS]);
    }
}

sub unpark {
    my ($mac,$ip) = @_;
    if(violation_close($mac, $PARKING_VID) != -1){
        unpark_actions($mac,$ip);
        return $TRUE;
    }
    else {
        get_logger->info("Device $mac cannot be unparked since the violation cannot be closed");
        return $FALSE;
    }
}

#rename to remove_parking_actions
sub unpark_actions {
    my ($mac, $ip) = @_;
    get_logger->info("Removing parking actions for $mac - $ip");
    my $omapi = pf::OMAPI->get_client();
    $omapi->delete_host($mac);

    pf_run("LANG=C sudo ipset del $PARKING_IPSET_NAME $ip -exist 2>&1");
}

1;

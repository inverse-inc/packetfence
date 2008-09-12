#
# Copyright 2007-2008 Inverse <support@inverse.ca>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::vlan;

use strict;
use warnings;

BEGIN {
    use Exporter ();
    our (@ISA, @EXPORT);
    @ISA    = qw(Exporter);
    @EXPORT = qw(vlan_determine_for_node);
}

use constant {
    CONF_FILE => "/usr/local/pf/conf/switches.conf",
    LOG_CONF_FILE => "/usr/local/pf/conf/log.conf",
    LOG_FILE => "/usr/local/pf/logs/pfsetvlan.log",
};
                                
use Log::Log4perl;

use lib qw(/usr/local/pf/lib);

use pf::config;
use pf::util;
use pf::db;
use pf::node qw(node_view);
use pf::violation qw(violation_count_trap);
use pf::SwitchFactory;

require "/usr/local/pf/conf/pfsetvlan.pm";

sub vlan_determine_for_node {
    my ($mac, $switch_ip, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger('pf::vlan');
    my $node_info = node_view($mac);

    my $correctVlanForThisMAC;
    if ((! defined($node_info)) || ($node_info->{'status'} ne 'reg')) {
        $logger->info("MAC: $mac is unregistered; belongs into registration VLAN");
        my $switchFactory = new pf::SwitchFactory( -configFile => CONF_FILE);
        my $switch = $switchFactory->instantiate($switch_ip);
        $correctVlanForThisMAC = $switch->{_registrationVlan};
    } else {
        my $open_violation_count = violation_count_trap($mac);
        if ($open_violation_count > 0) {
            $logger->info("$mac has $open_violation_count open violations(s) with action=trap; belongs into isolation VLAN.");
            my $switchFactory = new pf::SwitchFactory( -configFile => CONF_FILE);
            my $switch = $switchFactory->instantiate($switch_ip);
            $correctVlanForThisMAC = $switch->{_isolationVlan};
        } else {
            $correctVlanForThisMAC = custom_getCorrectVlan($switch_ip, $ifIndex, $mac, $node_info->{status}, $node_info->{vlan}, $node_info->{pid});
            $logger->info("MAC: $mac, PID: " . $node_info->{pid} . ", Status: " . $node_info->{status} . ", VLAN: $correctVlanForThisMAC");
        }
    }
    return $correctVlanForThisMAC;
}

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

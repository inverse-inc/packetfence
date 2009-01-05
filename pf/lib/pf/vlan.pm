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

use Log::Log4perl;

use pf::config;
use pf::node qw(node_view node_add_simple node_exist);
use pf::util;
use pf::violation qw(violation_count_trap violation_exist_open);
use pf::SwitchFactory;
use threads;

require "$conf_dir/pfsetvlan.pm";

sub vlan_determine_for_node {
    my ($mac, $switch_ip, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger('pf::vlan');
    Log::Log4perl::MDC->put('tid', threads->self->tid());

    my $correctVlanForThisMAC;
    my $open_violation_count = violation_count_trap($mac);
    if ($open_violation_count > 0) {
        if (($open_violation_count == 1) && (violation_exist_open($mac,1200001))) {
            $logger->info("$mac has scan reg violation open; belongs into registration VLAN.");
            my $switchFactory = new pf::SwitchFactory( -configFile => "$conf_dir/switches.conf");
            my $switch = $switchFactory->instantiate($switch_ip);
            $correctVlanForThisMAC = $switch->{_registrationVlan};
        } else {
            $logger->info("$mac has $open_violation_count open violations(s) with action=trap; belongs into isolation VLAN.");
            my $switchFactory = new pf::SwitchFactory( -configFile => "$conf_dir/switches.conf");
            my $switch = $switchFactory->instantiate($switch_ip);
            $correctVlanForThisMAC = $switch->{_isolationVlan};
       }
    } else {
        if (! node_exist($mac)) {
            $logger->info("node $mac does not yet exist in PF database. Adding it now");
            node_add_simple($mac);
        }
        my $node_info = node_view($mac);
        if (isenabled($Config{'trapping'}{'registration'})) {
            if ((! defined($node_info)) || ($node_info->{'status'} eq 'unreg')) {
                $logger->info("MAC: $mac is unregistered; belongs into registration VLAN");
                my $switchFactory = new pf::SwitchFactory( -configFile => "$conf_dir/switches.conf");
                my $switch = $switchFactory->instantiate($switch_ip);
                $correctVlanForThisMAC = $switch->{_registrationVlan};
            } else {
                $correctVlanForThisMAC = custom_getCorrectVlan($switch_ip, $ifIndex, $mac, $node_info->{status}, $node_info->{vlan}, $node_info->{pid});
                $logger->info("MAC: $mac, PID: " . $node_info->{pid} . ", Status: " . $node_info->{status} . ", VLAN: $correctVlanForThisMAC");
            }
        } else {
            my $switchFactory = new pf::SwitchFactory( -configFile => "$conf_dir/switches.conf");
            my $switch = $switchFactory->instantiate($switch_ip);
            $correctVlanForThisMAC = custom_getCorrectVlan($switch_ip, $ifIndex, $mac, $node_info->{status}, ($node_info->{vlan} || $switch->{_normalVlan}), $node_info->{pid});
            $logger->info("MAC: $mac, PID: " . $node_info->{pid} . ", Status: " . $node_info->{status} . ", VLAN: $correctVlanForThisMAC");
        }
    }
    return $correctVlanForThisMAC;
}

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

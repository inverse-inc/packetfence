package pf::trap::up;

=head1 NAME

pf::trap::up add documentation

=cut

=head1 DESCRIPTION

pf::trap::up

=cut

use strict;
use warnings;
use Moo;
extends 'pf::trap';

use pf::log;
use pf::config;
use pf::floatingdevice::custom;
use pf::inline::custom $INLINE_API_LEVEL;
use pf::locationlog;
use pf::node;
use pf::Switch 2.00;
use pf::Switch::constants;
use pf::SwitchFactory;
use pf::traplog;
use pf::util;
use pf::services::util;
use pf::violation;
use pf::vlan::custom $VLAN_API_LEVEL;
our %switch_locker;

=head2 supportedOIDS

Returns the list of supported OIDS for this trap

=cut

sub supportedOIDS { qw(.1.3.6.1.6.3.1.1.5.4) }

=head2 handle

handle the

=cut

sub handle {
    my ($self) = @_;
    my $logger= get_logger;
    my $switch_port = $self->ifIndex;
    my $switch = $self->switch;
    my $trapType = ref($self);
    my $switch_id = $switch->{_id};
    $logger->info("$trapType trap received on $switch_id ifIndex $switch_port");

    if ($switch->isPortSecurityEnabled($switch_port)) {
        $logger->info(
            "security traps are configured on this switch port. Stopping UP trap handling here"
        );
        cleanupAfterThread($switch_id, $switch_port);
        $switch->disconnectRead();
        $switch->disconnectWrite();
        return;
    }

    # if the last device pluggoed in that port is a floating network device then we handle it
    my @locationlog_switchport =
      locationlog_view_open_switchport_no_VoIP($switch_id, $switch_port);
    my $valid_locationlog_entry =
      (@locationlog_switchport && ref($locationlog_switchport[0]) eq 'HASH');
    if ($valid_locationlog_entry
        && (exists($ConfigFloatingDevices{$locationlog_switchport[0]->{mac}}))
      ) {
        $logger->info(
            "The logs shows that the last device pluged was a floating network device. We may have missed"
              . "the LinkDown trap. Disabling floating network device configuration on the port."
        );
        my $floatingDeviceManager = pf::floatingdevice::custom->new;

        # shut the port down
        $logger->debug("Shuting down port $switch_port");
        if (!$switch->setAdminStatus($switch_port, $SNMP::DOWN)) {
            $logger->error(
                "An error occured while shuting down port $switch_port. The port may not work!"
            );
        }

        my $result =
          $floatingDeviceManager->disablePortConfig(
            $locationlog_switchport[0]->{mac},
            $switch, $switch_port, \%switch_locker);

        if (!$result) {
            $logger->error(
                "An error occured while disabling floating network device configuration on port "
                  . " $switch_port. The port may not work!");
        }

        # open the port
        $logger->debug("Re-opening port $switch_port");
        if (!$switch->setAdminStatus($switch_port, $SNMP::UP)) {
            $logger->error(
                "An error occured while opening port $switch_port. The port may not work!"
            );
        }

        cleanupAfterThread($switch_id, $switch_port);
        $switch->disconnectRead();
        $switch->disconnectWrite();
        return;
    }
    $logger->info(
        "setting $switch_id port $switch_port to MAC detection VLAN");
    $switch->setMacDetectionVlan($switch_port, \%switch_locker, 1);

    if ($switch->isLearntTrapsEnabled($switch_port)) {
        $logger->info(
            "MAC learnt traps are configured on this switch port. Stopping UP trap handling here"
        );
        cleanupAfterThread($switch_id, $switch_port);
        $switch->disconnectRead();
        $switch->disconnectWrite();
        return;
    }

    my $nbAttempts = 0;
    my $start      = time;
    my @macArray   = ();
    my $secureMacAddrHashRef;
    do {
        sleep($switch->{_macSearchesSleepInterval})
          unless ($nbAttempts == 0);
        $logger->debug("attempt "
              . ($nbAttempts + 1)
              . " to obtain MAC at $switch_id ifIndex $switch_port");
        @macArray = $switch->_getMacAtIfIndex($switch_port);
        $nbAttempts++;

        # TODO constantify the 120 seconds
      } while (($nbAttempts < $switch->{_macSearchesMaxNb})
        && ((time - $start) < 120)
        && (scalar(@macArray) == 0));

    if (scalar(@macArray) == 0) {
        if ($nbAttempts >= $switch->{_macSearchesMaxNb}) {
            $logger->warn("Tried to grab MAC address at ifIndex $switch_port "
                  . "on switch "
                  . $switch->{_id} . " "
                  . $switch->{_macSearchesMaxNb}
                  . " times and failed");
        } else {
            $logger->warn("Tried to grab MAC address at ifIndex $switch_port "
                  . "on switch "
                  . $switch->{_id}
                  . " for 2 minutes and failed");
        }
    }

    my @tmpMacArray = ();
    if (scalar(@macArray) > 0) {

        #remove VoIP phones from list

        foreach my $currentMac (@macArray) {
            if ($switch->isPhoneAtIfIndex($currentMac, $switch_port)) {

                #this Mac is a phone
                $logger->debug("$currentMac is a phone");
                node_update_PF($switch, $switch_port, $currentMac, '', $TRUE,
                    $switch->isRegistrationMode());
            } else {
                push(@tmpMacArray, $currentMac);
                node_update_PF($switch, $switch_port, $currentMac, '', $FALSE,
                    $switch->isRegistrationMode());
            }
        }
    }
    @macArray = @tmpMacArray;

    if (scalar(@macArray) > 1) {
        $logger->info("several MACs found. Do nothing");

    } elsif (scalar(@macArray) == 1) {

        my $mac = lc($macArray[0]);

        do_port_security($mac, $switch, $switch_port, $trapType);

        node_determine_and_set_into_VLAN($mac, $switch, $switch_port,
            $WIRED_SNMP_TRAPS);

    } else {
        $logger->info(
            "cannot find MAC (maybe we found a VoIP, but they don't count here). Do nothing"
        );
    }

}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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


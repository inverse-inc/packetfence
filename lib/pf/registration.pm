package pf::registration;

=head1 NAME

pf::registration - node registration logic

=cut

=head1 DESCRIPTION

pf::registration

The module to place all node registration logic

=cut

use strict;
use warnings;
use pf::error;
use pf::StatsD;
use pf::StatsD::Timer;
use pf::log;
use pf::person;
use pf::lookup::person;
use pf::security_event;
use pf::constants::node qw($STATUS_REGISTERED);
use pf::util;
use pf::util::statsd qw(called);
use pf::dal::person;
use pf::Connection::ProfileFactory; 
use pf::constants::scan qw($SCAN_SECURITY_EVENT_ID $POST_SCAN_SECURITY_EVENT_ID);
use pf::constants::parking qw($PARKING_SECURITY_EVENT_ID);

=head2 setup_node_for_registration

setup a node for registration

=cut

sub setup_node_for_registration {
    $pf::StatsD::statsd->increment( called() . ".called" );
    my $timer = pf::StatsD::Timer->new();
    my ($node, $info) = @_;
    my $logger = get_logger();
    my $mac = $node->mac;

    my $status_msg = "";
    my $pid = $node->pid;

    if ( $node->{__old_data}->{status} ne "reg" &&  pf::node::is_max_reg_nodes_reached($mac, $pid, $node->category, $node->category_id) ) {
        $status_msg = "max nodes per pid met or exceeded";
        $logger->error( "$status_msg - registration of $mac to $pid failed" );
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }
    $node->status($STATUS_REGISTERED);
    $node->regdate(mysql_date());

    return ($STATUS::OK, "");
}

=head2 finalize_node_registration

do the node registration after saving

=cut

sub finalize_node_registration {
    my ($node, $info, $options, $context) = @_;

    do_person_create($node, $info, $context);
    # Closing any parking security_events
    pf::security_event::security_event_force_close($node->mac, $PARKING_SECURITY_EVENT_ID);

    do_security_event_scans($node, $options);

    return ;
}

=head2 do_person_create

do the person create step of node registration

=cut

sub do_person_create {
    my ($node, $info, $context) = @_;
    my $pid = $node->pid;
    my ($status, $person) = pf::dal::person->find_or_create({"pid" => $pid});
    if ($status == $STATUS::CREATED ) {
        pf::lookup::person::async_lookup_person($pid, $node->{'source'}, $context);
    }
    if ($person) {
        $person->source($node->{source});
        $person->portal($node->{portal});
        $person->save;
    }
}

=head2 do_security_event_scans

do security_event scans for a node

=cut

sub do_security_event_scans {
    my ($node_obj, $options) = @_;
    my $mac = $node_obj->mac;
    my $logger = get_logger();
    my $profile = pf::Connection::ProfileFactory->instantiate($node_obj, $options);
    my $scan = $profile->findScan($mac);
    if (defined($scan)) {
        # triggering a security_event used to communicate the scan to the user
        if ( isenabled($scan->{'registration'})) {
            $logger->debug("Triggering on registration scan");
            pf::security_event::security_event_add( $mac, $SCAN_SECURITY_EVENT_ID );
        }
        if (isenabled($scan->{'post_registration'})) {
            $logger->debug("Triggering post-registration scan");
            pf::security_event::security_event_add( $mac, $POST_SCAN_SECURITY_EVENT_ID );
        }
    }
    return ;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

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


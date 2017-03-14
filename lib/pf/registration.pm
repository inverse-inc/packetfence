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
use pf::violation;
use pf::constants::node qw($STATUS_REGISTERED);
use pf::util;
use pf::dal::person;
use pf::Portal::ProfileFactory; 
use pf::constants::scan qw($SCAN_VID $POST_SCAN_VID);
use pf::constants::parking qw($PARKING_VID);

=head2 register_node

register a node and do the following actions

* Create a user and sync it's information with the source
* If not auto reg trigger any scans for it's profile

=cut

sub register_node {
    my $timer = pf::StatsD::Timer->new();
    my ($node, $info) = @_;
    my $logger = get_logger();
    my $mac = $node->mac;
    my $auto_registered = 0;

    my $status_msg = "";
    my $pid = $node->pid;

    my ($status, $person) = pf::dal::person->find_or_create({"pid" => $pid});

    if ($status == $STATUS::CREATED ) {
        pf::lookup::person::async_lookup_person($pid, $info->{'source'});
    }
    if ($person) {
        $person->source($info->{source});
        $person->portal($info->{portal});
        $person->save;
    }

    # if it's for auto-registration and mac is already registered, we are done
    if ($info->{'autoreg'}) {
        $node->autoreg('yes');
        if ($node->status eq 'reg' ) {
            $status = $node->save;
            $status_msg = '';
            if (is_error($status)) {
                $status_msg = "modify of node $mac failed";
                $logger->error($status_msg);
            }
            return ($status, $status_msg);
        }
    }
    else {
    # do not check for max_node if it's for auto-register
        if ( is_max_reg_nodes_reached($mac, $pid, $node->category, $node->category_id) ) {
            $status_msg = "max nodes per pid met or exceeded";
            $logger->error( "$status_msg - registration of $mac to $pid failed" );
            return ($STATUS::PRECONDITION_FAILED, $status_msg);
        }
    }

    $node->status($STATUS_REGISTERED);
    $node->regdate(mysql_date());
    $status = $node->save;

    if (is_error($status)) {
        $status_msg = "modify of node $mac failed";
        $logger->error($status_msg);
        return ($status, $status_msg);
    }
    $pf::StatsD::statsd->increment( called() . ".called" );

    # Closing any parking violations
    pf::violation::violation_force_close($mac, $PARKING_VID);

    do_violation_scans($node);

    return ($STATUS::OK, "");
}

=head2 do_violation_scans

do violation scans for a node

=cut

sub do_violation_scans {
    my ($node_obj) = @_;
    my $mac = $node_obj->mac;
    my $logger = get_logger();
    my $profile = pf::Portal::ProfileFactory->instantiate($node_obj);
    my $scan = $profile->findScan($mac);
    if (defined($scan)) {
        # triggering a violation used to communicate the scan to the user
        if ( isenabled($scan->{'registration'})) {
            $logger->debug("Triggering on registration scan");
            pf::violation::violation_add( $mac, $SCAN_VID );
        }
        if (isenabled($scan->{'post_registration'})) {
            $logger->debug("Triggering post-registration scan");
            pf::violation::violation_add( $mac, $POST_SCAN_VID );
        }
    }
    return ;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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


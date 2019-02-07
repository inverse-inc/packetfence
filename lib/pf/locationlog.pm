package pf::locationlog;

=head1 NAME

pf::locationlog - module for MAC-Switch-Port-VLAN logging.

=cut

=head1 DESCRIPTION

pf::locationlog contains the functions necessary to manage the
MAC-Switch-Port-VLAN history.

=cut

use strict;
use warnings;
use pf::log;
use pf::floatingdevice::custom;
use pf::StatsD::Timer;
use pf::util::statsd qw(called);
use pf::CHI::Request;
use CHI::Memoize qw(memoize memoized);

use constant LOCATIONLOG => 'locationlog';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(
        $locationlog_db_prepared
        locationlog_db_prepare

        locationlog_history_mac
        locationlog_history_switchport

        locationlog_view_open
        locationlog_view_open_mac
        locationlog_view_open_switchport
        locationlog_view_open_switchport_no_VoIP
        locationlog_view_open_switchport_only_VoIP

        locationlog_close_all
        locationlog_cleanup

        locationlog_insert_start
        locationlog_update_end
        locationlog_update_end_mac
        locationlog_update_end_switchport_no_VoIP
        locationlog_update_end_switchport_only_VoIP
        locationlog_synchronize

        locationlog_set_session
        locationlog_get_session
        locationlog_last_entry_mac
        
        locationlog_unique_ssids
    );
}

use pf::config qw(
    $WIRED
    $NO_VOIP
    $VOIP
);
use pf::db;
use pf::dal;
use pf::dal::locationlog;
use pf::error qw(is_error is_success);
use pf::node;
use pf::util;
use pf::config::util;
use pf::constants;

=head1 DATA FORMAT

TODO: list incomplete

=over

=item dot1x_username

RADIUS' User-Name attribute only popuplated if connection was EAP (802.1X) and the user successfully authenticated.
Max length is 255 bytes according to RFC2865.

=item ssid (Service Set Identifier)

Identifies the Wireless Network related to the RADIUS Access-Request.
The field is not standardized so depending on your hardware it might not be properly populated.
See our RADIUS' module find_ssid() documentation for more information about this.
Max length is 32 bytes according to IEEE 802.11-1999.

=back

=head1 SUBROUTINES

TODO: list incomplete

=over

=cut

# TODO: extract this out of here and into pf::pfcmd::report
# think about web ui and pfcmd
sub locationlog_history_mac {
    my ( $mac, %params ) = @_;
    $mac = clean_mac($mac);

    require pf::pfcmd::report;
    import pf::pfcmd::report;
    my $where = {
        mac => $mac,
    };
    my ($start_time, $end_time);

    if ( defined( $params{'date'} ) ) {
        $start_time = $end_time = $params{'date'};
    } elsif ( defined( $params{'start_time'} ) && defined( $params{'end_time'} ) ) {
        $start_time = $params{'start_time'};
        $end_time = $params{'end_time'};
    }
    if ($start_time && $end_time) {
        $where->{start_time} = { "<" => \['from_unixtime(?)', $end_time] };
        $where->{end_time} = { ">" => \['from_unixtime(?)', $start_time] };
    }

    return translate_connection_type(_db_list({
        -columns => [
            qw(mac switch switch_ip switch_mac port vlan role connection_type connection_sub_type dot1x_username ssid start_time end_time stripped_user_name realm ifDesc
              UNIX_TIMESTAMP(start_time)|start_timestamp
              UNIX_TIMESTAMP(end_time)|end_timestamp)
        ],
        -where => $where,
        -order_by => [{-desc => 'start_time'}, {-desc => 'end_time'}],
        -limit => 25,
    }));
}

# TODO: extract this out of here and into pf::pfcmd::report
# think about web ui and pfcmd
sub locationlog_history_switchport {
    my ( $switch, %params ) = @_;

    require pf::pfcmd::report;
    import pf::pfcmd::report;
    my $where = {
        switch => $switch,
        port => $params{'ifIndex'},
    };
    my $date = $params{'date'};
    if ( defined($date)) {
        $where->{start_time} = { "<" => \['from_unixtime(?)', $date] };
        $where->{end_time} = { ">" => \['from_unixtime(?)', $date] };
    }
    return translate_connection_type(_db_list({
        -columns => [
            qw(mac switch switch_ip switch_mac port vlan role connection_type connection_sub_type dot1x_username ssid start_time end_time stripped_user_name realm ifDesc)
        ],
        -where => $where,
        -order_by => [{-desc => 'start_time'}, {-desc => 'end_time'}],
    }));
}

sub locationlog_view_open {
    return _db_list({
        -where => {
            end_time => $ZERO_DATE,
        },
        -order_by => { -desc => 'start_time' },
    });
}

sub locationlog_view_open_switchport {
    my ( $switch, $ifIndex, $voip ) = @_;
    return _db_list({
        -where => {
            switch => $switch,
            port => $ifIndex,
            'node.voip' => $voip,
            end_time => $ZERO_DATE,
        },
        -from => [-join => 'locationlog', '<={locationlog.mac=node.mac,locationlog.tenant_id=node.tenant_id}', 'node'],
        -order_by => { -desc => 'start_time' },
    });
}

sub locationlog_view_open_switchport_no_VoIP {
    my ( $switch, $ifIndex ) = @_;
    return _db_list({
        -where => {
            switch => $switch,
            port => $ifIndex,
            'node.voip' => { "!=" => "yes"},
            end_time => $ZERO_DATE,
        },
        -from => [-join => 'locationlog', '<={locationlog.mac=node.mac,locationlog.tenant_id=node.tenant_id}', 'node'],
        -order_by => { -desc => 'start_time' },
    });
}

sub locationlog_view_open_switchport_only_VoIP {
    my ( $switch, $ifIndex ) = @_;
    return _db_item({
        -where => {
            switch => $switch,
            port => $ifIndex,
            'node.voip' => "yes",
            end_time => $ZERO_DATE,
        },
        -from => [-join => 'locationlog', '<={locationlog.mac=node.mac,locationlog.tenant_id=node.tenant_id}', 'node'],
        -limit => 1,
        -order_by => { -desc => 'start_time' },
    });
}

sub locationlog_view_open_mac {
    my ($mac) = @_;
    $mac = clean_mac($mac);
    return _db_item({
        -where => {
            mac => $mac,
            end_time => $ZERO_DATE,
        },
        -limit => 1,
        -order_by => { -desc => 'start_time' },
    });
}

sub locationlog_insert_start {
    my ( $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, $locationlog_mac, $ifDesc ) = @_;
    my $logger = get_logger();

    my $conn_type = connection_type_to_str($connection_type)
        or $logger->info("Asked to insert a locationlog entry with connection type unknown.");

    # warning avoidance
    $user_name = "" if (!defined($user_name));
    $ssid = "" if (!defined($ssid));

    if (!(defined($vlan)) && defined($locationlog_mac->{'vlan'})) {
        $vlan = $locationlog_mac->{'vlan'};
    }
    my %values = (
        switch              => $switch,
        switch_ip           => $switch_ip,
        switch_mac          => $switch_mac,
        port                => $ifIndex,
        vlan                => $vlan,
        role                => $role,
        connection_sub_type => $connection_sub_type,
        connection_type     => $conn_type,
        dot1x_username      => $user_name,
        ssid                => $ssid,
        stripped_user_name  => $stripped_user_name,
        realm               => $realm,
        ifDesc              => $ifDesc,
        start_time          => \'NOW()',
    );
    if ( defined($mac) ) {
        $values{mac} = lc($mac);
    }
    my $status = pf::dal::locationlog->create(\%values);
    return (is_success($status));
}

sub locationlog_update_end {
    my ( $switch, $ifIndex, $mac ) = @_;

    my $logger = get_logger();
    if ( defined($mac) ) {
        $logger->info("locationlog_update_end called with mac=$mac");
        locationlog_update_end_mac($mac);
    } else {
        $logger->info("locationlog_update_end called without mac");
        my ($status, $rows) = pf::dal::locationlog->update_items(
            -set => {
                end_time => \'NOW()',
            },
            -where => {
                port => $ifIndex,
                switch => $switch,
            }
        );
    }
    return (1);
}

sub locationlog_update_end_switchport_no_VoIP {
    my ( $switch, $ifIndex ) = @_;
    my ($status, $rows) = pf::dal::locationlog->update_items(
        -set => {
            end_time => \'NOW()',
        },
        -where => {
            switch => $switch,
            port => $ifIndex,
            'node.voip' => {"!=" => "yes"},
            end_time => $ZERO_DATE,
        },
        -table => [-join => 'locationlog', '<={locationlog.mac=node.mac,locationlog.tenant_id=node.tenant_id}', 'node'],
    );
    return ($rows);
}

sub locationlog_update_end_switchport_only_VoIP {
    my ( $switch, $ifIndex ) = @_;

    my ($status, $rows) = pf::dal::locationlog->update_items(
        -set => {
            end_time => \'NOW()',
        },
        -where => {
            switch => $switch,
            port => $ifIndex,
            'node.voip' => "yes",
            end_time => $ZERO_DATE,
        },
        -table => [-join => 'locationlog', '<={locationlog.mac=node.mac,locationlog.tenant_id=node.tenant_id}', 'node'],
    );
    return ($rows);
}

sub locationlog_update_end_mac {
    my ($mac, $tenant_id) = @_;
    my %options = (
        -set => {
            end_time => \'NOW()',
        },
        -where => {
            mac => $mac,
            end_time => $ZERO_DATE,
        }
    );
    if (defined $tenant_id) {
        $options{-where}{tenant_id} = $tenant_id;
        $options{-no_auto_tenant_id} = 1;
    }

    my ($status, $rows) = pf::dal::locationlog->update_items(%options);
    return ($rows);
}

=item * locationlog_synchronize

synchronize locationlog to current values if necessary

 $voip_status expects VOIP / NO_VOIP constants

=cut

sub locationlog_synchronize {
    my $timer = pf::StatsD::Timer->new({ sample_rate => 0.2 });
    my ( $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, $ifDesc) = @_;

    $voip_status = $NO_VOIP if !defined $voip_status || $voip_status ne $VOIP; #Set the default voip status
    my $logger = get_logger();
    $logger->trace(sub {"sync locationlog with ifDesc " . ($ifDesc // "undef")});
    $logger->trace("locationlog_synchronize called");

    # flag to determine if we must insert a new record or not
    my $mustInsert = 0;
    my $inserted = 0;

    if ( defined($mac) ) {

        $mac = lc($mac);

        # grab latest open locationlog entry
        my $locationlog_mac = locationlog_view_open_mac($mac);
        if (defined($locationlog_mac) && ref($locationlog_mac) eq 'HASH') {
            $logger->trace("existing open locationlog entry");

            # did something changed?
            if (!_is_locationlog_accurate($locationlog_mac, $switch, $ifIndex, $vlan,
                $mac, $connection_type, $connection_sub_type, $user_name, $ssid, $role)) {

                #If the last connection was inline then make sure to clean ipset
                if ( ( (str_to_connection_type($locationlog_mac->{connection_type}) & $pf::config::INLINE) == $pf::config::INLINE ) && !($connection_type && ($connection_type & $pf::config::INLINE) == $pf::config::INLINE) ) {
                    $logger->debug("Unmark node in ipset session since the connection type changed from inline to something else");
                    my $inline = new pf::inline::custom();
                    my $mark = $inline->{_technique}->get_mangle_mark_for_mac($mac);
                    $inline->{_technique}->iptables_unmark_node($mac,$mark) if (defined($mark));
                }

                $logger->debug("closing old locationlog entry because something about this node changed");

                unless (defined (locationlog_update_end_mac($mac))) {
                    return (0);
                }
                locationlog_insert_start($switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, $locationlog_mac, $ifDesc);

                # We just inserted an entry so we won't want to add another one
                $inserted = 1;
            }

        } else {
            $mustInsert = 1;
            $logger->debug("no open locationlog entry, we need to insert a new one");
        }

        if ( !node_exist($mac) ) {
            node_add_simple($mac);
        }
    }

    # if we are in a wired environment, close any conflicting switchport entry
    # but paying attention to VoIP vs non-VoIP entries (we close the same type that we are asked to add)
    if ($connection_type && ($connection_type & $WIRED) == $WIRED) {
        my $floatingDeviceManager = new pf::floatingdevice::custom();
        if( $floatingDeviceManager->portHasFloatingDevice($switch_ip, $ifIndex) ){
            $logger->info("Not adding locationlog entry for mac $mac because it's plugged in a floating device enabled port");
            return 1;
        }

        my @locationlog_switchport = locationlog_view_open_switchport($switch, $ifIndex, $voip_status);
        if (!(@locationlog_switchport && scalar(@locationlog_switchport) > 0)) {
            # there was no locationlog open we must insert a new one
            $mustInsert = 1;

        } elsif (($locationlog_switchport[0]->{vlan} ne $vlan) # vlan changed
            || (defined($mac) && (!defined($locationlog_switchport[0]->{mac})))
            || (defined($locationlog_switchport[0]->{role}) && ($locationlog_switchport[0]->{role} ne $role) ) ) { # or Role changed

            # close entries of same voip status
            if ($voip_status eq $NO_VOIP) {
                locationlog_update_end_switchport_no_VoIP($switch, $ifIndex);
            } else {
                locationlog_update_end_switchport_only_VoIP($switch, $ifIndex);
            }
            $mustInsert = 1;
        }
    }

    # we insert a locationlog entry
    if ($mustInsert && !$inserted) {
        locationlog_insert_start($switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role, undef, $ifDesc)
            or $logger->warn("Unable to insert a locationlog entry.");
    }
    return 1;
}

sub locationlog_close_all {
    my ($status, $rows) = pf::dal::locationlog->update_items(
        -set => {
            end_time => \'NOW()',
        },
        -where => {
            end_time => $ZERO_DATE,
        }
    );
    return ($rows);
}

sub locationlog_cleanup {
    my $timer = pf::StatsD::Timer->new({ sample_rate => 0.2 });
    my ($expire_seconds, $batch, $time_limit) = @_;
    my $logger = get_logger();
    $logger->debug("calling locationlog_cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit");

    if($expire_seconds eq "0") {
        $logger->debug("Not deleting because the window is 0");
        return;
    }

    my $now = pf::dal->now();

    my ($status, $rows) = pf::dal::locationlog->batch_remove(
        {
            -where => {
                end_time => {
                     "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ] ,
                     "!=" => $ZERO_DATE,
                },
            },
            -limit => $batch,
        },
        $time_limit
    );
    return ($rows);
}

=item * _is_locationlog_accurate

return 1 if locationlog entry is accurate, 0 otherwise

=cut

# Note: voip_status was removed from the accuracy check, feel free to revisit this assumption if we face VoIP problems
sub _is_locationlog_accurate {
    my $timer = pf::StatsD::Timer->new({ sample_rate => 0.05, level => 7 });
    my ( $locationlog_mac, $switch, $ifIndex, $vlan, $mac, $connection_type, $connection_sub_type, $user_name, $ssid, $role ) = @_;
    my $logger = get_logger();
    $logger->trace("verifying if locationlog is accurate called");

    # avoid undef warnings during tests by setting undef values to empty string
    $user_name = '' if (!defined($user_name));
    $ssid = '' if (!defined($ssid));

    # did something changed
    my $vlanChanged = '0';
    if (defined($vlan)) {
        $vlanChanged = (exists($locationlog_mac->{'vlan'}) && defined($locationlog_mac->{'vlan'}) &&  $locationlog_mac->{'vlan'} ne $vlan);
    }
    my $switchChanged = ($locationlog_mac->{'switch'} ne $switch);
    my $conn_typeChanged = ($locationlog_mac->{connection_type} ne connection_type_to_str($connection_type));
    my $userChanged = ($locationlog_mac->{'dot1x_username'} ne $user_name);
    my $ssidChanged = ($locationlog_mac->{'ssid'} ne $ssid);

    my $roleChanged = '0';
    my $old_role = $locationlog_mac->{'role'};
    $roleChanged = (
        (!defined($old_role) && defined($role))
        || (defined($old_role) && !defined($role))
        || (defined($old_role) && defined($role) && $old_role ne $role)
    );

    # ifIndex on wireless is not important
    my $ifIndexChanged = 0;
    if (($connection_type & $WIRED) == $WIRED) {
        $ifIndexChanged = ($locationlog_mac->{port} ne $ifIndex);
    }

    if ($vlanChanged || $switchChanged || $conn_typeChanged || $ifIndexChanged || $userChanged || $ssidChanged || $roleChanged) {
        $logger->trace("latest locationlog entry is not accurate");
        return 0;
    } else {
        $logger->debug("latest locationlog entry is still accurate");
        return 1;
    }
}

sub locationlog_get_session {
    my ( $session_id ) = @_;
    return _db_item({
        -where => {
            session_id => $session_id,
            end_time => $ZERO_DATE,
        },
        -order_by => { -desc => 'start_time' },
        -limit => 1,
    });
}

sub locationlog_set_session {
    my ( $mac, $session_id ) = @_;
    my ($status, $rows) = pf::dal::locationlog->update_items(
       -set => {
           session_id => $session_id,
       },
       -where => {
           mac => $mac,
           end_time => $ZERO_DATE,
       }
   );
   return $rows;
}

=item locationlog_last_entry_mac

Return the last locationlog entry for a mac even if it's open or close.

=cut

sub locationlog_last_entry_mac {
   my ($mac) = @_;
   $mac = clean_mac($mac);
   return _db_item({
       -where => {
           mac => $mac,
       },
       -order_by => { -desc => 'start_time' },
       -limit => 1,
   });
}

sub _db_item {
    my ($args) = @_;
    my ($status, $iter) = pf::dal::locationlog->search(%$args);

    if (is_error($status)) {
        return (0);
    }
    return ($iter->next(undef));
}

sub _db_list {
    my ($args) = @_;
    my ($status, $iter) = pf::dal::locationlog->search(%$args);
    if (is_error($status)) {
        return;
    }
    return @{$iter->all(undef) // []};
}

=item locationlog_unique_ssids

Return a list of unique SSIDs that have been seen.

=cut

sub locationlog_unique_ssids {
    return map { $_->{ssid} } _db_list({
        -columns => [ -distinct => 'ssid' ],
        -where   => {
            ssid => { "!=" => [ -and => "", undef ] },
        },
        -order_by => 'ssid',
    });
}

=back

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

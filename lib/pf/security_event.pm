package pf::security_event;

=head1 NAME

pf::security_event - module for security_event management.

=cut

=head1 DESCRIPTION

pf::security_event contains the functions necessary to manage security_events: creation,
deletion, expiration, read info, ...

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use pf::log;
use Readonly;
use POSIX;
use JSON;
use Time::HiRes qw(time);
use pfconfig::cached_scalar;
use fingerbank::Model::Device;
use fingerbank::Model::DHCP_Fingerprint;
use fingerbank::Model::DHCP_Vendor;
use fingerbank::Model::User_Agent;
use pf::security_event_config;
use pf::node;
use pf::StatsD::Timer;


# SecurityEvent status constants
#TODO port all hard-coded strings to these constants
#but first I need to resolve the exporting problems..
#ex: when trying to use these from node I get subroutines redefinitions
#    and if I use full package names, there is no safety that the constant was defined in the first place..
Readonly::Scalar our $STATUS_OPEN => 'open';
Readonly::Scalar our $STATUS_DELAYED => 'delayed';

use pf::factory::condition::security_event;
pf::factory::condition::security_event->modules;
tie our $SECURITY_EVENT_FILTER_ENGINE , 'pfconfig::cached_scalar' => 'FilterEngine::SecurityEvent';

our %POST_OPEN_ACTIONS = (
    "1300003" => sub {
        my ($info) = @_;
        require pf::parking;
        my $mac = $info->{mac};
        pf::parking::park($mac, pf::ip4log::mac2ip($mac));
    },
);
our %POST_CLOSE_ACTIONS = (
    "1300003" => sub {
        my ($info) = @_;
        require pf::parking;
        my $mac = $info->{mac};
        pf::parking::remove_parking_actions($mac, pf::ip4log::mac2ip($mac));
    },
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        security_event_db_prepare
        $security_event_db_prepared

        security_event_force_close
        security_event_close
        security_event_view
        security_event_view_all
        security_event_add
        security_event_view_open
        security_event_view_open_desc
        security_event_view_open_uniq
        security_event_view_desc
        security_event_modify
        security_event_trigger
        security_event_count
        security_event_count_reevaluate_access
        security_event_view_top
        security_event_delete
        security_event_exist_open
        security_event_exist_acct
        security_event_exist_id
        security_event_view_last_closed
        security_event_maintenance
        security_event_add_warnings
        security_event_clear_warnings
        security_event_last_warnings
        security_event_add_errors
        security_event_clear_errors
        security_event_last_errors
        security_event_run_delayed
        security_event_count_security_event_id
        security_event_count_open_security_event_id
    );
}
use pf::action;
use pf::accounting qw($ACCOUNTING_TRIGGER_RE);
use pf::class qw(class_view);
use pf::constants qw(
    $TRUE
    $FALSE
    $ZERO_DATE
);
use pf::enforcement;
use pf::db;
use pf::dal::security_event;
use pf::error qw(is_error is_success);
use pf::constants::scan qw($SCAN_SECURITY_EVENT_ID $POST_SCAN_SECURITY_EVENT_ID $PRE_SCAN_SECURITY_EVENT_ID);
use pf::constants::role qw($REGISTRATION_ROLE);
use pf::util;
use pf::config::util;
use pf::client;
use pf::security_event_config;

our @ERRORS;
our @WARNINGS;

=head1 SUBROUTINES

=over

This list is incomplete.

=cut

#
sub security_event_modify {
    my ( $id, %data ) = @_;
    my $logger = get_logger();

    return (0) if ( !$id );
    my ($status, $existing) = pf::dal::security_event->find_or_create({
        %data,
        id => $id,
    });

    if (is_error($status)) {
        return (0);
    }

    if ($status == $STATUS::CREATED) {
        $logger->warn(
            "modify of non-existent security_event $id attempted - security_event added"
        );
        return (2);
    }

    # Check if the security_event was open or closed
    my $was_closed = ($existing->{status} eq 'closed') ? 1 : 0;
    $existing->merge(\%data);

    $logger->info( "security_event for mac "
            . $existing->{mac} . " security_event_id "
            . $existing->{security_event_id}
            . " modified" );

    # Handle the release date case on the modify (from the GUI)
    if ($data{status} eq 'closed' && !$was_closed && $existing->{release_date} eq '') {
        $existing->{release_date} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time));
    } elsif ($data{status} eq 'open' && $was_closed) {
        $existing->{release_date} = $ZERO_DATE;
    }

    $status = $existing->save();

    return (is_success($status));
}

sub security_event_grace {
    my ( $mac, $security_event_id ) = @_;
    my ($status, $iter) = pf::dal::security_event->search(
        -where => {
            'status' => "closed",
            'security_event.security_event_id' => $security_event_id,
            'mac' => $mac,
        },
        -columns => ['unix_timestamp(start_date)+grace_period-unix_timestamp(now())|grace'],
        -from => [-join => qw(security_event =>{security_event.security_event_id=class.security_event_id} class)],
        -order_by => {-desc => "start_date"},
    );
    my $grace = $iter->next(undef);
    return ($grace ? $grace->{grace} : 0);
}

sub security_event_count {
    my ($mac) = @_;
    my ($status, $count) = pf::dal::security_event->count(
        -where => {
            mac => $mac,
            status => "open",
        }
    );

    return ($count);
}

sub security_event_count_reevaluate_access {
    my ($mac) = @_;
    my ($status, $count) = pf::dal::security_event->count(
        -where => {
            mac => $mac,
            status => "open",
            'action.action' => 'reevaluate_access',
            'security_event.security_event_id' => { -ident => 'action.security_event_id'},
        },
        -from => [qw(security_event action)],
    );

    return ($count);
}

sub security_event_count_security_event_id {
    my ( $mac, $security_event_id ) = @_;
    my ($status, $count) = pf::dal::security_event->count(
        -where => {
            mac => $mac,
            security_event_id => $security_event_id,
        }
    );

    return ($count);
}

sub security_event_count_open_security_event_id {
    my ( $mac, $security_event_id ) = @_;
    my ($status, $count) = pf::dal::security_event->count(
        -where => {
            mac => $mac,
            security_event_id => $security_event_id,
            status => "open",
        }
    );

    return ($count);
}

sub security_event_exist {
    my ( $mac, $security_event_id, $start_date ) = @_;
    return _db_item({
        -where => {
            mac => $mac,
            security_event_id => $security_event_id,
            start_date => $start_date
        },
        -columns => [qw(id mac security_event_id start_date release_date status ticket_ref notes)],
        -limit => 1,
        -no_default_join => 1,
    });
}

sub security_event_exist_id {
    my ($id) = @_;
    return _db_item({
        -where => {
            id => $id,
        },
        -columns => [qw(id mac security_event_id start_date release_date status ticket_ref notes)],
        -limit => 1,
        -no_default_join => 1,
    });
}

sub security_event_exist_open {
    my ( $mac, $security_event_id ) = @_;
    return _db_item({
        -where => {
            security_event_id => $security_event_id,
            mac => $mac,
            status => 'open',
        },
        -columns => [qw(id mac security_event_id start_date release_date status ticket_ref notes)],
        -no_default_join => 1,
        -limit => 1,
    });
}

sub security_event_view {
    my ($id) = @_;
    return _db_data({
        -where => {
            'security_event.mac' => {-ident => 'node.mac'},
            'security_event.id' => $id, 
        },
        -columns => [qw(security_event.id security_event.mac node.computername security_event.security_event_id security_event.start_date security_event.release_date security_event.status security_event.ticket_ref security_event.notes)],
        -from => [qw(security_event node)],
    });
}

sub security_event_view_top {
    my ($mac) = @_;
    return _db_item({
        -where => {
            mac => $mac,
            status => 'open',
        },
        -columns => [qw(id mac security_event.security_event_id start_date release_date status ticket_ref notes)],
        -from => [-join => qw(security_event {security_event.security_event_id=class.security_event_id} class)],
        -order_by => {-asc => 'priority'},
        -limit => 1,
    });
}

sub security_event_view_open {
    my ($mac) = @_;
    return _db_data({
        -where => {
            status => "open",
            mac => $mac,
        },
        -columns => [qw(id mac security_event_id start_date release_date status ticket_ref notes)],
        -order_by => { -desc => 'start_date' },
        -no_default_join => 1,
    });
}

sub security_event_view_open_desc {
    my ($mac) = @_;
    return _db_data({
        -where => {
            status => "open",
            mac => $mac,
        },
        -columns => [qw(id start_date class.description security_event.security_event_id status)],
        -from => [-join => qw(security_event <=>{security_event.security_event_id=class.security_event_id} class)],
        -order_by => { -desc => 'start_date' },
    });
}

=item security_event_view_open_uniq

Returns a list of MACs which have at least one opened security_event.
Since trap security_events stay open, this has the intended effect of getting all MACs which should be isolated.

=cut

sub security_event_view_open_uniq {
    return _db_data({
        -where => {
            status => "open",
        },
        -group_by => "mac",
        -columns => [qw(mac)],
    });
}

sub security_event_view_desc {
    my ($mac) = @_;
    return _db_data({
        -where => {
            mac => $mac,
        },
        -columns => [qw(id start_date release_date class.description security_event.security_event_id status)],
        -from => [-join => qw(security_event <=>{security_event.security_event_id=class.security_event_id} class)],
        -order_by => {-desc => 'start_date'},
    });
}

#
sub security_event_add {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $mac, $security_event_id, %data ) = @_;
    my $logger = get_logger();
    return (0) if ( !$security_event_id );
    security_event_clear_warnings();
    security_event_clear_errors();

    #defaults
    $data{start_date} = mysql_date()
        if ( !defined $data{start_date} || !$data{start_date} );
    $data{release_date} = $ZERO_DATE if ( !defined $data{release_date} );
    $data{status} = "open" if ( !defined $data{status} || !$data{status} );
    $data{notes}  = ""     if ( !defined $data{notes} );
    $data{ticket_ref} = "" if ( !defined $data{ticket_ref} );

    if ( my $security_event =  security_event_exist_open( $mac, $security_event_id ) ) {
        my $msg = "security_event $security_event_id already exists for $mac, not adding again";
        $logger->info($msg);
        security_event_add_warnings($msg);
        return ($security_event->{security_event_id});
    }

    my $latest_security_event = ( security_event_view_open($mac) )[0];
    my $latest_security_event_id       = $latest_security_event->{'security_event_id'};
    if ($latest_security_event_id) {

        # don't add a hostscan if security_event exists
        if ( $security_event_id == $SCAN_SECURITY_EVENT_ID || $security_event_id == $POST_SCAN_SECURITY_EVENT_ID || $security_event_id == $PRE_SCAN_SECURITY_EVENT_ID) {
            $logger->warn(
                "hostscan detected from $mac, but security_event $latest_security_event_id exists - ignoring"
            );
            return (1);
        }

        #replace UNKNOWN hostscan with known security_event
        if ( $latest_security_event_id == $SCAN_SECURITY_EVENT_ID || $latest_security_event_id == $POST_SCAN_SECURITY_EVENT_ID || $latest_security_event_id == $PRE_SCAN_SECURITY_EVENT_ID) {
            $logger->info(
                "security event $security_event_id detected for $mac - updating existing hostscan entry"
            );
            security_event_force_close( $mac, $latest_security_event_id );
        }
    }

    # if this node doesn't exist we'll run into problems so create it
    if ( !node_exist($mac) ) {
        node_add_simple($mac);
    } else {

        # check if we are under the grace period of a previous security_event
        my ($remaining_time) = security_event_grace( $mac, $security_event_id );
        my $force = defined $data{'force'} ? $data{'force'} : $FALSE;
        if ( $remaining_time > 0 && $force ne $TRUE ) {
            my $msg = "$remaining_time grace remaining on security event $security_event_id for node $mac. Not adding security_event.";
            security_event_add_errors($msg);
            $logger->info($msg);
            return (-1);
        } elsif ( $remaining_time > 0 && $force eq $TRUE ) {
            my $msg = "Force security event $security_event_id for node $mac even if $remaining_time grace remaining";
            $logger->info($msg);
        } else {
            my $msg = "grace expired on security event $security_event_id for node $mac";
            $logger->info($msg);
        }
    }

    # insert security_event into db
    my $status = pf::dal::security_event->create({
        mac          => $mac,
        security_event_id          => $security_event_id,
        start_date   => $data{start_date},
        release_date => $data{release_date},
        status       => $data{status},
        ticket_ref   => $data{ticket_ref},
        notes        => $data{notes}
    });
    if (is_success($status)) {
        my $last_id = get_db_handle->last_insert_id(undef,undef,undef,undef);
        $logger->info("security event $security_event_id added for $mac");
        if($data{status} eq 'open') {
            pf::action::action_execute( $mac, $security_event_id, $data{notes} );
            security_event_post_open_action($mac, $security_event_id);
        }
        return ($last_id);
    } else {
        my $msg = "unknown error adding security event $security_event_id for $mac";
        security_event_add_errors($msg);
        $logger->error($msg);
    }
    return (0);
}

=item security_event_add_warnings

=cut

sub security_event_add_warnings { push @WARNINGS,@_; }


=item security_event_clear_warnings

=cut

sub security_event_clear_warnings { @WARNINGS = (); }

=item security_event_last_warnings

=cut

sub security_event_last_warnings { @WARNINGS }

=item security_event_add_errors

=cut

sub security_event_add_errors { push @ERRORS,@_; }


=item security_event_clear_errors

=cut

sub security_event_clear_errors { @ERRORS = (); }

=item security_event_last_errors

=cut

sub security_event_last_errors { @ERRORS }

sub info_for_security_event_engine {
    # NEED TO HANDLE THE NEW TID
    my ($mac,$type,$tid) = @_;
    my $node_info = pf::node::node_view($mac);

    my $cache = pf::CHI->new( namespace => 'fingerbank' );

    $type = lc($type);

    my $devices = [];
    my ($device_id);
    if($type eq "device"){
        $device_id = $tid;
    }
    else {
        my ($device_result, $device) = fingerbank::Model::Device->find([{name => $node_info->{device_type}}]);
        if(is_success($device_result)){
            $device_id = $device->id
        }
    }

    my $attr_map = {
        dhcp_fingerprint => "fingerbank::Model::DHCP_Fingerprint",
        dhcp_vendor => "fingerbank::Model::DHCP_Vendor",
        dhcp6_fingerprint => "fingerbank::Model::DHCP6_Fingerprint",
        dhcp6_enterprise => "fingerbank::Model::DHCP6_Enterprise",
        user_agent => "fingerbank::Model::User_Agent",
    };
    my $results = {};
    foreach my $attr (keys %$attr_map){
        my $model = $attr_map->{$attr};
        my $query = {value => $node_info->{$attr}};
        $results->{$attr} = $cache->compute_with_undef("$model\_id_".encode_json($query), sub {
            my ($status, $result) = $model->find([$query]);
            return is_success($status) ? $result->id : undef;
        });
    }
    my ($mac_vendor_id) = $cache->compute_with_undef("mac_vendor_id_from_mac_$mac", sub {
        my $mac_vendor = pf::fingerbank::mac_vendor_from_mac($mac);
        return $mac_vendor ? $mac_vendor->id : undef;
    });

    my $accounting_history = pf::accounting_events_history->new->latest_mac_history($mac);

    my $info = {
      device_id => $device_id,
      dhcp_fingerprint_id => $results->{dhcp_fingerprint},
      dhcp_vendor_id => $results->{dhcp_vendor},
      dhcp6_fingerprint_id => $results->{dhcp6_fingerprint},
      dhcp6_enterprise_id => $results->{dhcp6_enterprise},
      mac => $mac,
      mac_vendor_id => $mac_vendor_id,
      user_agent_id => $results->{user_agent},
      last_switch => $node_info->{'last_switch'},
      role => $node_info->{category},
      last_accounting_events => $accounting_history,
    };

    my $trigger_info = $pf::factory::condition::security_event::TRIGGER_TYPE_TO_CONDITION_TYPE{$type};
    if( $trigger_info->{type} ne 'includes' ){
        $info->{$trigger_info->{key}} = $tid;
    }

    return $info;
}

=item * security_event_trigger

Evaluates a candidate security_event and if its valid, will add it to the node and trigger a VLAN change if required

Returns 1 if at least one security_event is added, 0 otherwise.

=cut

sub security_event_trigger {
    my $timer = pf::StatsD::Timer->new({level => 6});

    my ( $argv ) = @_;
    my $logger = get_logger();

    # Making sure we have all required arguments to process a security_event triggering
    my @require = qw(mac tid type);
    my @found = grep {exists $argv->{$_}} @require;
    return (0) unless pf::util::validate_argv(\@require, \@found);

    my $mac = $argv->{'mac'};
    my $tid = $argv->{'tid'};
    my $type = $argv->{'type'};

    $logger->trace("Triggering security_event $type $tid for mac $mac");
    return (0) if ( !$tid );
    $type = lc($type);

    if (whitelisted_mac($mac)) {
        $logger->info("security_event not added, $mac is whitelisted! trigger ${type}::${tid}");
        return 0;
    }

    if (!valid_mac($mac)) {
        $logger->info("security_event not added, MAC $mac is invalid! trigger ${type}::${tid}");
        return 0;
    }

    if (!trappable_mac($mac)) {
        $logger->info("security_event not added, MAC $mac is not trappable! trigger ${type}::${tid}");
        return 0;
    }

    my $info = info_for_security_event_engine($mac,$type,$tid);

    $logger->debug(sub { use Data::Dumper; "Infos for security_event engine : ".Dumper($info) });
    my @security_event_ids = $SECURITY_EVENT_FILTER_ENGINE->match_all($info);

    my $addedSecurityEvent = 0;
    foreach my $security_event_id (@security_event_ids) {
        if (_is_node_category_whitelisted($security_event_id, $mac)) {
            $logger->info("Not adding security_event ${security_event_id} node $mac is whitelisted because of its role");
            next;
        }

        # we test here AND in security_event_add because here we avoid a fork (and security_event_add is called from elsewhere)
        if ( security_event_exist_open( $mac, $security_event_id ) ) {
            $logger->info("security_event $security_event_id (trigger ${type}::${tid}) already exists for $mac, not adding again");
            next;
        }

        # check if we are under the grace period of a previous security_event
        # we test here AND in security_event_add because here we avoid a fork (and security_event_add is called from elsewhere)
        my ($remaining_time) = security_event_grace( $mac, $security_event_id );
        if ($remaining_time > 0) {
            $logger->info(
                "$remaining_time grace remaining on security_event $security_event_id (trigger ${type}::${tid}) for node $mac. " .
                "Not adding security_event."
            );
            next;
        }

        # if security_event is of action autoreg and the node is already registered
        if (pf::action::action_exist($security_event_id, $pf::action::AUTOREG) && is_node_registered($mac)) {
            $logger->debug(
                "security_event $security_event_id triggered with action $pf::action::AUTOREG but node $mac is already registered. " .
                "Not adding security_event."
            );
            next;
        }
        # Compute the release date
        my $date = 0;
        my %data;

        my $class = class_view($security_event_id);
        # Check if the security_event is delayed
        if ($class->{'delay_by'}) {
            $data{status} = 'delayed';
            $date = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $class->{'delay_by'}));
        }
        # Check if we have a window defined for the security_event, and act properly
        # TODO: Handle the "dynamic" keyword
        elsif (defined($class->{'window'})) {
          if ($class->{'window'} ne 'dynamic' && $class->{'window'} ne '0' ) {
            $date = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $class->{'window'}));
          } elsif ($class->{'window'} eq 'dynamic' && $type eq "accounting") {
            # Funky calculus here
            $tid =~ /$ACCOUNTING_TRIGGER_RE/;

            if (defined($4)) {
                if ($4 eq 'D'){
                    $date = POSIX::strftime("%Y-%m-%d 23:59:59", localtime(time));
                } elsif ($4 eq 'W') {
                    $date = POSIX::strftime("%Y-%m-%d 23:59:59", localtime(time + (6-(localtime(time))[6])*3600*24));
                } elsif ($4 eq 'M') {
                    my $curMonth = (localtime())[4];
                    my $curYear = (localtime())[5];
                    my @time = localtime(POSIX::mktime(0,0,0,0,$curMonth+1,$curYear,0,0,-1));

                    $date = POSIX::strftime("%Y-%m-$time[3] 23:59:59", localtime(time));
                } elsif ($4 eq 'Y') {
                    $date = POSIX::strftime("%Y-12-31 23:59:59", localtime(time));
                }
            }
            # no interval given so we assume from beginning of time (10 years)
          }
        }
        $data{'release_date'} = $date;

        $data{'notes'} = $argv->{'notes'} if defined($argv->{'notes'});

        $logger->info("calling security_event_add with security_event_id=$security_event_id mac=$mac release_date=$date (trigger ${type}::${tid})");
        security_event_add($mac, $security_event_id, %data);
        $addedSecurityEvent = 1;
    }
    return $addedSecurityEvent;
}

sub security_event_delete {
    my ($id) = @_;
    my $status = pf::dal::security_event->remove_by_id({id => $id});
    return (is_success($status));
}

sub security_event_scaning {
    my ( $mac , $security_event_id) = @_;
    my $logger = get_logger();

    my $test_query = security_event_exist_open($mac,$security_event_id);

    return (1) if(defined($test_query) && $test_query->{notes} eq 'scaning');
    
    my ($status, $rows) = pf::dal::security_event->update_items(
        -set => {
            notes => 'scaning',
        },
        -where => {
            mac => $mac,
            security_event_id => $security_event_id,
            status => { "!=" => "closed"},
        }
        );

    return ( (is_success($status)) ? (0) : (1) );
}

#return -1 on failure, because grace=0 is unlimited
#
sub security_event_close {
    my ( $mac, $security_event_id ) = @_;
    my $logger = get_logger();
    require pf::class;
    my $class_info = pf::class::class_view($security_event_id);

    # check auto_enable = 'N'
    if ( $class_info->{'auto_enable'} =~ /^N$/i ) {
        return (-1);
    }

    #check the number of security_events
    my $num = security_event_count_security_event_id( $mac, $security_event_id );
    my $max = $class_info->{'max_enables'};

    if ( $num <= $max || $max == 0 ) {

        my $grace = $class_info->{'grace_period'};
        my ($status, $rows) = pf::dal::security_event->update_items(
            -set => {
                release_date => \'NOW()',
                status => 'closed',
            },
            -where => {
                mac => $mac,
                security_event_id => $security_event_id,
                status => { "!=" => "closed"},
            }
        );
        $logger->info("security_event $security_event_id closed for $mac");
        security_event_post_close_action($mac, $security_event_id);
        return ($grace);
    }
    return (-1);
}

# use force close to definitely shut a security_event
# used for non-trap security_event and to close scan security_events
#
sub security_event_force_close {
    my ( $mac, $security_event_id ) = @_;
    my $logger = get_logger();

    my $should_run_actions = security_event_exist_open($mac, $security_event_id);
    my ($status, $rows) = pf::dal::security_event->update_items(
        -set => {
            release_date => \'NOW()',
            status => 'closed',
        },
        -where => {
            mac => $mac,
            security_event_id => $security_event_id,
            status => { "!=" => "closed"},
        }
    );
    $logger->info("security_event $security_event_id force-closed for $mac");
    if($should_run_actions) {
        security_event_post_close_action($mac, $security_event_id);
    }
    return (1);
}

=item * security_event_exist_acct - check if a closed security_event exists within the accounting interval window

=cut

sub security_event_exist_acct {
    my ( $mac, $security_event_id, $interval ) = @_;
    my $ceil;

    if ($interval eq "daily") {
       $ceil = POSIX::strftime("%Y-%m-%d 00:00:00",localtime(time));
    } elsif ($interval eq "weekly") {
       $ceil = POSIX::strftime("%Y-%m-%d 00:00:00",localtime(time - (localtime(time))[6]*24*3600));
    } elsif ($interval eq "monthly") {
       $ceil = POSIX::strftime("%Y-%m-01 00:00:00",localtime(time));
    } elsif ($interval eq "yearly") {
       $ceil = POSIX::strftime("%Y-01-01 00:00:00",localtime(time));
    } else {
       $ceil = 0;
    }
    
    return _db_item({
        -where => {
            mac => $mac,
            security_event_id => $security_event_id,
            release_date => {
                ">=" => $ceil,
                "<=" => \'NOW()',
            },
        },
        -no_default_join => 1,
        -columns => [qw(id)],
    });
}

=item * security_event_view_last_closed - grab the last closed security_event within the accounting interval window

=cut

sub security_event_view_last_closed {
    my ( $mac, $security_event_id ) = @_;

    return _db_data({
        -where => {
            mac => $mac,
            security_event_id => $security_event_id,
            status => "closed",
        },
        -order_by => {-desc => 'release_date'} ,
        -columns => [qw(mac security_event_id release_date)],
        -no_default_join => 1,
    });
}

=item * _is_node_category_whitelisted - is a node immune to a given security_event based on its category

=cut

sub _is_node_category_whitelisted {
    my ($security_event_id, $mac) = @_;
    my $logger = get_logger();

    my $class = $pf::security_event_config::SecurityEvent_Config{$security_event_id};

    # if whitelist is empty, node is not whitelisted
    if (!defined($class->{'whitelisted_roles'}) || @{$class->{'whitelisted_roles'}} == 0) {
        return 0;
    }

    # Grabbing the node's informations (incl. role)
    # Note: consider extracting out of here and putting in security_event_trigger and passing node_info hashref instead
    my $node_info = node_attributes($mac);
    if(!defined($node_info) || ref($node_info) ne 'HASH') {
        $logger->warn("Something went wrong trying to fetch the node info");
        return 0;
    }

    my $node_role = $node_info->{category};
    # matching registration role for unregistered devices
    if($node_info->{status} eq $pf::node::STATUS_UNREGISTERED) {
        $node_role = $REGISTRATION_ROLE;
    }

    # trying to match node's category on whitelisted categories
    my $role_found = 0;
    # whitelisted_roles is of the form "cat1,cat2,cat3,etc."
    foreach my $role (@{$class->{'whitelisted_roles'}}) {
        if (lc($role) eq lc($node_role)) {
            $role_found = 1;
        }
    }

    return $role_found;
}

=item security_event_maintenance

Check if we should close security_events based on release_date

=cut

sub security_event_maintenance {
    my ($batch,$timelimit) = @_;
    my $logger = get_logger();

    $logger->debug("Looking at expired security_events... batching $batch timelimit $timelimit");
    my $start_time = time;
    my $end_time;
    my $rows_processed = 0;
    while(1) {
        my ($status, $iter) = pf::dal::security_event->search(
            -where => {
                status => ["open", "delayed"],
                release_date => [-and => {"!=" => $ZERO_DATE}, {"<=" => \'NOW()'}],
            },
           -limit => $batch,
           -columns => [qw(id mac security_event_id notes status)],
           -no_default_join => 1,
        );
        if (is_error($status)) {
            last;
        }
        my $rows = $iter->sth->rows;
        my $client = pf::client::getClient();
        while (my $row = $iter->next(undef)) {
            if($row->{status} eq 'delayed' ) {
                $client->notify(security_event_delayed_run => ($row));
            }
            else {
                my $mac = $row->{mac};
                my $security_event_id = $row->{security_event_id};
                my $result = security_event_force_close($mac,$security_event_id);
                # If close is a success, reevaluate the Access for the node
                if ($result) {
                    pf::enforcement::reevaluate_access( $mac, "manage_vclose" );
                }
            }
        }
        $rows_processed+=$rows;
        $end_time = time;
        $logger->trace( sub { "processed $rows_processed security_events during security_event maintenance ($start_time $end_time) " });
        last if $rows <= 0 || (($end_time - $start_time) > $timelimit);
    }
    $logger->info(  "processed $rows_processed security_events during security_event maintenance ($start_time $end_time) " );
    return (1);
}

sub security_event_run_delayed {
    my ($id) = @_;
    my ($security_event) = security_event_view($id);
    if($security_event) {
        _security_event_run_delayed($security_event);
        return 1;
    }
    return 0;
}

sub _security_event_run_delayed {
    my ($security_event) = @_;
    my $logger = get_logger();
    my $mac = $security_event->{mac};
    my $security_event_id = $security_event->{security_event_id};
    my %data = (status => 'open');
    my $class = pf::class::class_view($security_event_id);
    if (defined($class->{'window'})) {
        my $date = 0;
        if ($class->{'window'} ne 'dynamic' && $class->{'window'} ne '0' ) {
            $date = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $class->{'window'}));
        }
        $data{release_date} = $date;
    }
    $logger->info("processing delayed security_event : $security_event->{id}, $security_event->{security_event_id}");
    my $notes = $security_event->{security_event_id};
    pf::security_event::security_event_modify($security_event->{id}, %data);
    pf::action::action_execute( $mac, $security_event_id, $notes );
}

=item security_event_post_open_action

Execute an action that should occur after opening the security_event if necessary

=cut

sub security_event_post_open_action {
    my ($mac, $security_event_id) = @_;
    if(exists($POST_OPEN_ACTIONS{$security_event_id})) {
        $POST_OPEN_ACTIONS{$security_event_id}->({mac => $mac, security_event_id => $security_event_id});
    }
}

=item security_event_post_close_action

Execute an action that should occur after closing the security_event if necessary

=cut

sub security_event_post_close_action {
    my ($mac, $security_event_id) = @_;
    if(exists($POST_CLOSE_ACTIONS{$security_event_id})) {
        $POST_CLOSE_ACTIONS{$security_event_id}->({mac => $mac, security_event_id => $security_event_id});
    }
}


=head2 _db_item

_db_item

=cut

sub _db_item {
    my ($args) = @_;
    my ($status, $iter) = pf::dal::security_event->search(%$args);
    if (is_error($status)) {
        return (0);
    }
    my $item = $iter->next(undef);
    return ($item);
}
=head2 _db_data

_db_data

=cut

sub _db_data {
    my ($args) = @_;
    my ($status, $iter) = pf::dal::security_event->search(%$args);
    if (is_error($status)) {
        return;
    }
    return @{$iter->all(undef) // []};
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

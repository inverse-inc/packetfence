package pf::violation;

=head1 NAME

pf::violation - module for violation management.

=cut

=head1 DESCRIPTION

pf::violation contains the functions necessary to manage violations: creation,
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
use pf::violation_config;
use pf::node;
use pf::StatsD::Timer;


# Violation status constants
#TODO port all hard-coded strings to these constants
#but first I need to resolve the exporting problems..
#ex: when trying to use these from node I get subroutines redefinitions
#    and if I use full package names, there is no safety that the constant was defined in the first place..
Readonly::Scalar our $STATUS_OPEN => 'open';
Readonly::Scalar our $STATUS_DELAYED => 'delayed';

use pf::factory::condition::violation;
pf::factory::condition::violation->modules;
tie our $VIOLATION_FILTER_ENGINE , 'pfconfig::cached_scalar' => 'FilterEngine::Violation';

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
        violation_db_prepare
        $violation_db_prepared

        violation_force_close
        violation_close
        violation_view
        violation_view_all
        violation_add
        violation_view_open
        violation_view_open_desc
        violation_view_open_uniq
        violation_view_desc
        violation_modify
        violation_trigger
        violation_count
        violation_count_reevaluate_access
        violation_view_top
        violation_delete
        violation_exist_open
        violation_exist_acct
        violation_exist_id
        violation_view_last_closed
        violation_maintenance
        violation_add_warnings
        violation_clear_warnings
        violation_last_warnings
        violation_add_errors
        violation_clear_errors
        violation_last_errors
        violation_run_delayed
        violation_count_vid
        violation_count_open_vid
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
use pf::dal::violation;
use pf::error qw(is_error is_success);
use pf::constants::scan qw($SCAN_VID $POST_SCAN_VID $PRE_SCAN_VID);
use pf::constants::role qw($REGISTRATION_ROLE);
use pf::util;
use pf::config::util;
use pf::client;
use pf::violation_config;

our @ERRORS;
our @WARNINGS;

=head1 SUBROUTINES

=over

This list is incomplete.

=cut

#
sub violation_modify {
    my ( $id, %data ) = @_;
    my $logger = get_logger();

    return (0) if ( !$id );
    my ($status, $existing) = pf::dal::violation->find_or_create({
        %data,
        id => $id,
    });

    if (is_error($status)) {
        return (0);
    }

    if ($status == $STATUS::CREATED) {
        $logger->warn(
            "modify of non-existent violation $id attempted - violation added"
        );
        return (2);
    }

    # Check if the violation was open or closed
    my $was_closed = ($existing->{status} eq 'closed') ? 1 : 0;
    $existing->merge(\%data);

    $logger->info( "violation for mac "
            . $existing->{mac} . " vid "
            . $existing->{vid}
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

sub violation_grace {
    my ( $mac, $vid ) = @_;
    my ($status, $iter) = pf::dal::violation->search(
        -where => {
            'status' => "closed",
            'violation.vid' => $vid,
            'mac' => $mac,
        },
        -columns => ['unix_timestamp(start_date)+grace_period-unix_timestamp(now())|grace'],
        -from => [-join => qw(violation =>{violation.vid=class.vid} class)],
        -order_by => {-desc => "start_date"},
    );
    my $grace = $iter->next(undef);
    return ($grace ? $grace->{grace} : 0);
}

sub violation_count {
    my ($mac) = @_;
    my ($status, $count) = pf::dal::violation->count(
        -where => {
            mac => $mac,
            status => "open",
        }
    );

    return ($count);
}

sub violation_count_reevaluate_access {
    my ($mac) = @_;
    my ($status, $count) = pf::dal::violation->count(
        -where => {
            mac => $mac,
            status => "open",
            'action.action' => 'reevaluate_access',
            'violation.vid' => { -ident => 'action.vid'},
        },
        -from => [qw(violation action)],
    );

    return ($count);
}

sub violation_count_vid {
    my ( $mac, $vid ) = @_;
    my ($status, $count) = pf::dal::violation->count(
        -where => {
            mac => $mac,
            vid => $vid,
        }
    );

    return ($count);
}

sub violation_count_open_vid {
    my ( $mac, $vid ) = @_;
    my ($status, $count) = pf::dal::violation->count(
        -where => {
            mac => $mac,
            vid => $vid,
            status => "open",
        }
    );

    return ($count);
}

sub violation_exist {
    my ( $mac, $vid, $start_date ) = @_;
    return _db_item({
        -where => {
            mac => $mac,
            vid => $vid,
            start_date => $start_date
        },
        -columns => [qw(id mac vid start_date release_date status ticket_ref notes)],
        -limit => 1,
        -no_default_join => 1,
    });
}

sub violation_exist_id {
    my ($id) = @_;
    return _db_item({
        -where => {
            id => $id,
        },
        -columns => [qw(id mac vid start_date release_date status ticket_ref notes)],
        -limit => 1,
        -no_default_join => 1,
    });
}

sub violation_exist_open {
    my ( $mac, $vid ) = @_;
    return _db_item({
        -where => {
            vid => $vid,
            mac => $mac,
            status => 'open',
        },
        -columns => [qw(id mac vid start_date release_date status ticket_ref notes)],
        -no_default_join => 1,
        -limit => 1,
    });
}

sub violation_view {
    my ($id) = @_;
    return _db_data({
        -where => {
            'violation.mac' => {-ident => 'node.mac'},
            'violation.id' => $id, 
        },
        -columns => [qw(violation.id violation.mac node.computername violation.vid violation.start_date violation.release_date violation.status violation.ticket_ref violation.notes)],
        -from => [qw(violation node)],
    });
}

sub violation_view_top {
    my ($mac) = @_;
    return _db_item({
        -where => {
            mac => $mac,
            status => 'open',
        },
        -columns => [qw(id mac violation.vid start_date release_date status ticket_ref notes)],
        -from => [-join => qw(violation {violation.vid=class.vid} class)],
        -order_by => {-asc => 'priority'},
        -limit => 1,
    });
}

sub violation_view_open {
    my ($mac) = @_;
    return _db_data({
        -where => {
            status => "open",
            mac => $mac,
        },
        -columns => [qw(id mac vid start_date release_date status ticket_ref notes)],
        -order_by => { -desc => 'start_date' },
        -no_default_join => 1,
    });
}

sub violation_view_open_desc {
    my ($mac) = @_;
    return _db_data({
        -where => {
            status => "open",
            mac => $mac,
        },
        -columns => [qw(id start_date class.description violation.vid status)],
        -from => [-join => qw(violation <=>{violation.vid=class.vid} class)],
        -order_by => { -desc => 'start_date' },
    });
}

=item violation_view_open_uniq

Returns a list of MACs which have at least one opened violation.
Since trap violations stay open, this has the intended effect of getting all MACs which should be isolated.

=cut

sub violation_view_open_uniq {
    return _db_data({
        -where => {
            status => "open",
        },
        -group_by => "mac",
        -columns => [qw(mac)],
    });
}

sub violation_view_desc {
    my ($mac) = @_;
    return _db_data({
        -where => {
            mac => $mac,
        },
        -columns => [qw(id start_date release_date class.description violation.vid status)],
        -from => [-join => qw(violation <=>{violation.vid=class.vid} class)],
        -order_by => {-desc => 'start_date'},
    });
}

#
sub violation_add {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $mac, $vid, %data ) = @_;
    my $logger = get_logger();
    return (0) if ( !$vid );
    violation_clear_warnings();
    violation_clear_errors();

    #defaults
    $data{start_date} = mysql_date()
        if ( !defined $data{start_date} || !$data{start_date} );
    $data{release_date} = $ZERO_DATE if ( !defined $data{release_date} );
    $data{status} = "open" if ( !defined $data{status} || !$data{status} );
    $data{notes}  = ""     if ( !defined $data{notes} );
    $data{ticket_ref} = "" if ( !defined $data{ticket_ref} );

    if ( my $violation =  violation_exist_open( $mac, $vid ) ) {
        my $msg = "violation $vid already exists for $mac, not adding again";
        $logger->info($msg);
        violation_add_warnings($msg);
        return ($violation);
    }

    my $latest_violation = ( violation_view_open($mac) )[0];
    my $latest_vid       = $latest_violation->{'vid'};
    if ($latest_vid) {

        # don't add a hostscan if violation exists
        if ( $vid == $SCAN_VID || $vid == $POST_SCAN_VID || $vid == $PRE_SCAN_VID) {
            $logger->warn(
                "hostscan detected from $mac, but violation $latest_vid exists - ignoring"
            );
            return (1);
        }

        #replace UNKNOWN hostscan with known violation
        if ( $latest_vid == $SCAN_VID || $latest_vid == $POST_SCAN_VID || $latest_vid == $PRE_SCAN_VID) {
            $logger->info(
                "violation $vid detected for $mac - updating existing hostscan entry"
            );
            violation_force_close( $mac, $latest_vid );
        }
    }

    # if this node doesn't exist we'll run into problems so create it
    if ( !node_exist($mac) ) {
        node_add_simple($mac);
    } else {

        # check if we are under the grace period of a previous violation
        my ($remaining_time) = violation_grace( $mac, $vid );
        my $force = defined $data{'force'} ? $data{'force'} : $FALSE;
        if ( $remaining_time > 0 && $force ne $TRUE ) {
            my $msg = "$remaining_time grace remaining on violation $vid for node $mac. Not adding violation.";
            violation_add_errors($msg);
            $logger->info($msg);
            return (-1);
        } elsif ( $remaining_time > 0 && $force eq $TRUE ) {
            my $msg = "Force violation $vid for node $mac even if $remaining_time grace remaining";
            $logger->info($msg);
        } else {
            my $msg = "grace expired on violation $vid for node $mac";
            $logger->info($msg);
        }
    }

    # insert violation into db
    my $status = pf::dal::violation->create({
        mac          => $mac,
        vid          => $vid,
        start_date   => $data{start_date},
        release_date => $data{release_date},
        status       => $data{status},
        ticket_ref   => $data{ticket_ref},
        notes        => $data{notes}
    });
    if (is_success($status)) {
        my $last_id = get_db_handle->last_insert_id(undef,undef,undef,undef);
        $logger->info("violation $vid added for $mac");
        if($data{status} eq 'open') {
            pf::action::action_execute( $mac, $vid, $data{notes} );
            violation_post_open_action($mac, $vid);
        }
        return ($last_id);
    } else {
        my $msg = "unknown error adding violation $vid for $mac";
        violation_add_errors($msg);
        $logger->error($msg);
    }
    return (0);
}

=item violation_add_warnings

=cut

sub violation_add_warnings { push @WARNINGS,@_; }


=item violation_clear_warnings

=cut

sub violation_clear_warnings { @WARNINGS = (); }

=item violation_last_warnings

=cut

sub violation_last_warnings { @WARNINGS }

=item violation_add_errors

=cut

sub violation_add_errors { push @ERRORS,@_; }


=item violation_clear_errors

=cut

sub violation_clear_errors { @ERRORS = (); }

=item violation_last_errors

=cut

sub violation_last_errors { @ERRORS }

sub info_for_violation_engine {
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
    };

    my $trigger_info = $pf::factory::condition::violation::TRIGGER_TYPE_TO_CONDITION_TYPE{$type};
    if( $trigger_info->{type} ne 'includes' ){
        $info->{$trigger_info->{key}} = $tid;
    }

    return $info;
}

=item * violation_trigger

Evaluates a candidate violation and if its valid, will add it to the node and trigger a VLAN change if required

Returns 1 if at least one violation is added, 0 otherwise.

=cut

sub violation_trigger {
    my $timer = pf::StatsD::Timer->new({level => 6});

    my ( $argv ) = @_;
    my $logger = get_logger();

    # Making sure we have all required arguments to process a violation triggering
    my @require = qw(mac tid type);
    my @found = grep {exists $argv->{$_}} @require;
    return (0) unless pf::util::validate_argv(\@require, \@found);

    my $mac = $argv->{'mac'};
    my $tid = $argv->{'tid'};
    my $type = $argv->{'type'};

    $logger->trace("Triggering violation $type $tid for mac $mac");
    return (0) if ( !$tid );
    $type = lc($type);

    if (whitelisted_mac($mac)) {
        $logger->info("violation not added, $mac is whitelisted! trigger ${type}::${tid}");
        return 0;
    }

    if (!valid_mac($mac)) {
        $logger->info("violation not added, MAC $mac is invalid! trigger ${type}::${tid}");
        return 0;
    }

    if (!trappable_mac($mac)) {
        $logger->info("violation not added, MAC $mac is not trappable! trigger ${type}::${tid}");
        return 0;
    }

    my $info = info_for_violation_engine($mac,$type,$tid);

    $logger->debug(sub { use Data::Dumper; "Infos for violation engine : ".Dumper($info) });
    my @vids = $VIOLATION_FILTER_ENGINE->match_all($info);

    my $addedViolation = 0;
    foreach my $vid (@vids) {
        if (_is_node_category_whitelisted($vid, $mac)) {
            $logger->info("Not adding violation ${vid} node $mac is whitelisted because of its role");
            next;
        }

        # we test here AND in violation_add because here we avoid a fork (and violation_add is called from elsewhere)
        if ( violation_exist_open( $mac, $vid ) ) {
            $logger->info("violation $vid (trigger ${type}::${tid}) already exists for $mac, not adding again");
            next;
        }

        # check if we are under the grace period of a previous violation
        # we test here AND in violation_add because here we avoid a fork (and violation_add is called from elsewhere)
        my ($remaining_time) = violation_grace( $mac, $vid );
        if ($remaining_time > 0) {
            $logger->info(
                "$remaining_time grace remaining on violation $vid (trigger ${type}::${tid}) for node $mac. " .
                "Not adding violation."
            );
            next;
        }

        # if violation is of action autoreg and the node is already registered
        if (pf::action::action_exist($vid, $pf::action::AUTOREG) && is_node_registered($mac)) {
            $logger->debug(
                "violation $vid triggered with action $pf::action::AUTOREG but node $mac is already registered. " .
                "Not adding violation."
            );
            next;
        }
        # Compute the release date
        my $date = 0;
        my %data;

        my $class = class_view($vid);
        # Check if the violation is delayed
        if ($class->{'delay_by'}) {
            $data{status} = 'delayed';
            $date = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $class->{'delay_by'}));
        }
        # Check if we have a window defined for the violation, and act properly
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

        $logger->info("calling violation_add with vid=$vid mac=$mac release_date=$date (trigger ${type}::${tid})");
        violation_add($mac, $vid, %data);
        $addedViolation = 1;
    }
    return $addedViolation;
}

sub violation_delete {
    my ($id) = @_;
    my $status = pf::dal::violation->remove_by_id({id => $id});
    return (is_success($status));
}

#return -1 on failure, because grace=0 is unlimited
#
sub violation_close {
    my ( $mac, $vid ) = @_;
    my $logger = get_logger();
    require pf::class;
    my $class_info = pf::class::class_view($vid);

    # check auto_enable = 'N'
    if ( $class_info->{'auto_enable'} =~ /^N$/i ) {
        return (-1);
    }

    #check the number of violations
    my $num = violation_count_vid( $mac, $vid );
    my $max = $class_info->{'max_enables'};

    if ( $num <= $max || $max == 0 ) {

        my $grace = $class_info->{'grace_period'};
        my ($status, $rows) = pf::dal::violation->update_items(
            -set => {
                release_date => \'NOW()',
                status => 'closed',
            },
            -where => {
                mac => $mac,
                vid => $vid,
                status => { "!=" => "closed"},
            }
        );
        $logger->info("violation $vid closed for $mac");
        violation_post_close_action($mac, $vid);
        return ($grace);
    }
    return (-1);
}

# use force close to definitely shut a violation
# used for non-trap violation and to close scan violations
#
sub violation_force_close {
    my ( $mac, $vid ) = @_;
    my $logger = get_logger();

    my $should_run_actions = violation_exist_open($mac, $vid);
    my ($status, $rows) = pf::dal::violation->update_items(
        -set => {
            release_date => \'NOW()',
            status => 'closed',
        },
        -where => {
            mac => $mac,
            vid => $vid,
            status => { "!=" => "closed"},
        }
    );
    $logger->info("violation $vid force-closed for $mac");
    if($should_run_actions) {
        violation_post_close_action($mac, $vid);
    }
    return (1);
}

=item * violation_exist_acct - check if a closed violation exists within the accounting interval window

=cut

sub violation_exist_acct {
    my ( $mac, $vid, $interval ) = @_;
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
            vid => $vid,
            release_date => {
                ">=" => $ceil,
                "<=" => \'NOW()',
            },
        },
        -no_default_join => 1,
        -columns => [qw(id)],
    });
}

=item * violation_view_last_closed - grab the last closed violation within the accounting interval window

=cut

sub violation_view_last_closed {
    my ( $mac, $vid ) = @_;

    return _db_data({
        -where => {
            mac => $mac,
            vid => $vid,
            status => "closed",
        },
        -order_by => {-desc => 'release_date'} ,
        -columns => [qw(mac vid release_date)],
        -no_default_join => 1,
    });
}

=item * _is_node_category_whitelisted - is a node immune to a given violation based on its category

=cut

sub _is_node_category_whitelisted {
    my ($vid, $mac) = @_;
    my $logger = get_logger();

    my $class = $pf::violation_config::Violation_Config{$vid};

    # if whitelist is empty, node is not whitelisted
    if (!defined($class->{'whitelisted_roles'}) || @{$class->{'whitelisted_roles'}} == 0) {
        return 0;
    }

    # Grabbing the node's informations (incl. role)
    # Note: consider extracting out of here and putting in violation_trigger and passing node_info hashref instead
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

=item violation_maintenance

Check if we should close violations based on release_date

=cut

sub violation_maintenance {
    my ($batch,$timelimit) = @_;
    my $logger = get_logger();

    $logger->debug("Looking at expired violations... batching $batch timelimit $timelimit");
    my $start_time = time;
    my $end_time;
    my $rows_processed = 0;
    while(1) {
        my ($status, $iter) = pf::dal::violation->search(
            -where => {
                status => ["open", "delayed"],
                release_date => [-and => {"!=" => $ZERO_DATE}, {"<=" => \'NOW()'}],
            },
           -limit => $batch,
           -columns => [qw(id mac vid notes status)],
           -no_default_join => 1,
        );
        if (is_error($status)) {
            last;
        }
        my $rows = $iter->sth->rows;
        my $client = pf::client::getClient();
        while (my $row = $iter->next(undef)) {
            if($row->{status} eq 'delayed' ) {
                $client->notify(violation_delayed_run => ($row));
            }
            else {
                my $mac = $row->{mac};
                my $vid = $row->{vid};
                my $result = violation_force_close($mac,$vid);
                # If close is a success, reevaluate the Access for the node
                if ($result) {
                    pf::enforcement::reevaluate_access( $mac, "manage_vclose" );
                }
            }
        }
        $rows_processed+=$rows;
        $end_time = time;
        $logger->trace( sub { "processed $rows_processed violations during violation maintenance ($start_time $end_time) " });
        last if $rows <= 0 || (($end_time - $start_time) > $timelimit);
    }
    $logger->info(  "processed $rows_processed violations during violation maintenance ($start_time $end_time) " );
    return (1);
}

sub violation_run_delayed {
    my ($id) = @_;
    my ($violation) = violation_view($id);
    if($violation) {
        _violation_run_delayed($violation);
        return 1;
    }
    return 0;
}

sub _violation_run_delayed {
    my ($violation) = @_;
    my $logger = get_logger();
    my $mac = $violation->{mac};
    my $vid = $violation->{vid};
    my %data = (status => 'open');
    my $class = pf::class::class_view($vid);
    if (defined($class->{'window'})) {
        my $date = 0;
        if ($class->{'window'} ne 'dynamic' && $class->{'window'} ne '0' ) {
            $date = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $class->{'window'}));
        }
        $data{release_date} = $date;
    }
    $logger->info("processing delayed violation : $violation->{id}, $violation->{vid}");
    my $notes = $violation->{vid};
    pf::violation::violation_modify($violation->{id}, %data);
    pf::action::action_execute( $mac, $vid, $notes );
}

=item violation_post_open_action

Execute an action that should occur after opening the violation if necessary

=cut

sub violation_post_open_action {
    my ($mac, $vid) = @_;
    if(exists($POST_OPEN_ACTIONS{$vid})) {
        $POST_OPEN_ACTIONS{$vid}->({mac => $mac, vid => $vid});
    }
}

=item violation_post_close_action

Execute an action that should occur after closing the violation if necessary

=cut

sub violation_post_close_action {
    my ($mac, $vid) = @_;
    if(exists($POST_CLOSE_ACTIONS{$vid})) {
        $POST_CLOSE_ACTIONS{$vid}->({mac => $mac, vid => $vid});
    }
}


=head2 _db_item

_db_item

=cut

sub _db_item {
    my ($args) = @_;
    my ($status, $iter) = pf::dal::violation->search(%$args);
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
    my ($status, $iter) = pf::dal::violation->search(%$args);
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

Copyright (C) 2005-2018 Inverse inc.

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

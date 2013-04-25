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
use Log::Log4perl;
use Readonly;
use POSIX;

# Violation status constants
#TODO port all hard-coded strings to these constants
#but first I need to resolve the exporting problems.. 
#ex: when trying to use these from node I get subroutines redefinitions 
#    and if I use full package names, there is no safety that the constant was defined in the first place..
Readonly::Scalar our $STATUS_OPEN => 'open';

use constant VIOLATION => 'violation';

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
        violation_count_all
        violation_view_all
        violation_view_all_active
        violation_view_open_all
        violation_add
        violation_view_open
        violation_view_open_desc
        violation_view_open_uniq
        violation_view_desc
        violation_modify
        violation_trigger
        violation_count
        violation_count_trap
        violation_view_top
        violation_delete
        violation_exist_open
        violation_exist_acct
        violation_exist_id
        violation_view_last_closed
        violation_maintenance
    );
}

use pf::action;
use pf::accounting qw($ACCOUNTING_TRIGGER_RE);
use pf::class qw(class_view);
use pf::config;
use pf::enforcement;
use pf::db;
use pf::node;
use pf::util;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $violation_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $violation_statements = {};

=head1 SUBROUTINES

This list is incomplete.

=cut

sub violation_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::violation');
    $logger->debug("Preparing pf::violation database queries");

    $violation_statements->{'violation_desc_sql'} = get_db_handle()->prepare(qq [ desc violation ]);

    $violation_statements->{'violation_add_sql'} = get_db_handle()->prepare(
        qq [ insert into violation(mac,vid,start_date,release_date,status,ticket_ref,notes) values(?,?,?,?,?,?,?) ]);

    $violation_statements->{'violation_modify_sql'} = get_db_handle()->prepare(
        qq [ update violation set mac=?,vid=?,start_date=?,release_date=?,status=?,ticket_ref=?,notes=? where id=? ]);

    $violation_statements->{'violation_exist_sql'} = get_db_handle()->prepare(
        qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? and vid=? and start_date=? ]);

    $violation_statements->{'violation_exist_open_sql'} = get_db_handle()->prepare(
        qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? and vid=? and status="open" order by vid asc ]);

    $violation_statements->{'violation_exist_id_sql'} = get_db_handle()->prepare(
        qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where id=? ]);

    $violation_statements->{'violation_view_sql'} = get_db_handle()->prepare(
        qq [ select violation.id,violation.mac,node.computername,violation.vid,violation.start_date,violation.release_date,violation.status,violation.ticket_ref,violation.notes from violation,node where violation.mac=node.mac and violation.id=? order by start_date desc ]);

    $violation_statements->{'violation_count_all_sql'} = qq[
        SELECT count(*) as nb
        FROM violation
    ];

    $violation_statements->{'violation_view_all_sql'} = get_db_handle()->prepare(qq[
        SELECT violation.id,violation.mac,node.computername,violation.vid,violation.start_date,violation.release_date,violation.status,violation.ticket_ref,violation.notes
        FROM violation,node 
        WHERE violation.mac=node.mac
        ORDER BY start_date DESC
    ]);

    $violation_statements->{'violation_view_open_sql'} = get_db_handle()->prepare(
        qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where mac=? and status="open" order by start_date desc ]);

    $violation_statements->{'violation_view_open_desc_sql'} = get_db_handle()->prepare(
        qq [ select v.id,v.start_date,c.description,v.vid,v.status from violation v inner join class c on v.vid=c.vid where v.mac=? and v.status="open" order by start_date desc ]);

    $violation_statements->{'violation_view_open_uniq_sql'} = get_db_handle()->prepare(
        qq [ select mac from violation where status="open" group by mac ]);

    $violation_statements->{'violation_view_open_all_sql'} = get_db_handle()->prepare(
        qq [ select id,mac,vid,start_date,release_date,status,ticket_ref,notes from violation where status="open" ]);

    $violation_statements->{'violation_view_desc_sql'} = get_db_handle()->prepare(qq[
        SELECT v.id,v.start_date,c.description,v.vid,v.status
        FROM violation v
        INNER JOIN class c ON v.vid=c.vid
        WHERE v.mac=? order by start_date desc
    ]);

    $violation_statements->{'violation_view_top_sql'} = get_db_handle()->prepare(qq[
        SELECT id, mac, v.vid, start_date, release_date, status, ticket_ref, notes 
        FROM violation v, class c 
        WHERE v.vid=c.vid AND mac=? AND status="open" 
        ORDER BY priority ASC LIMIT 1
    ]);

    $violation_statements->{'violation_view_all_active_sql'} = get_db_handle()->prepare(
        qq [ select v.mac,v.vid,v.start_date,v.release_date,v.status,v.ticket_ref,v.notes,i.ip,i.start_time,i.end_time from violation v left join iplog i on v.mac=i.mac where v.status="open" and i.end_time=0 group by v.mac]);

    $violation_statements->{'violation_delete_sql'} = get_db_handle()->prepare(qq [ delete from violation where id=? ]);

    $violation_statements->{'violation_close_sql'} = get_db_handle()->prepare(
        qq [ update violation set release_date=now(),status="closed" where mac=? and vid=? and status="open" ]);

    $violation_statements->{'violation_grace_sql'} = get_db_handle()->prepare(
        qq [ select unix_timestamp(start_date)+grace_period-unix_timestamp(now()) from violation v left join class c on v.vid=c.vid where mac=? and v.vid=? and status="closed" order by start_date desc ]);

    $violation_statements->{'violation_count_sql'} = get_db_handle()->prepare(
        qq [ select count(*) from violation where mac=? and status="open" ]);

    $violation_statements->{'violation_count_trap_sql'} = get_db_handle()->prepare(
        qq [ select count(*) from violation, action where violation.vid=action.vid and action.action='trap' and mac=? and status="open" ]);

    $violation_statements->{'violation_count_vid_sql'} = get_db_handle()->prepare(
        qq [ select count(*) from violation where mac=? and vid=? ]);

    $violation_statements->{'violation_release_sql'} = get_db_handle()->prepare(
        qq [ select mac,vid from violation where release_date !=0 AND release_date <= NOW() AND status = "open" ]);

    $violation_statements->{'violation_last_closed_sql'} = get_db_handle()->prepare(
        qq [ select mac,vid,release_date from violation where mac = ? AND vid = ? AND status = "closed" ORDER BY release_date DESC LIMIT 1 ]);
    
    $violation_statements->{'violation_exist_acct_sql'} = get_db_handle()->prepare(
        qq [ select id from violation where mac = ? AND vid = ? AND release_date >= ? AND release_date <= NOW()]);

    $violation_db_prepared = 1;
    return 1;
}

#
#
sub violation_desc {
    return db_data(VIOLATION, $violation_statements, 'violation_desc_sql');
}

#
sub violation_modify {
    my ( $id, %data ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::violation');

    return (0) if ( !$id );
    my $existing = violation_exist_id($id);

    if ( !$existing ) {
        if ( violation_add( $data{mac}, $data{vid}, %data ) ) {
            $logger->warn(
                "modify of non-existent violation $id attempted - violation added"
            );
            return (2);
        } else {
            $logger->error(
                "modify of non-existent violation $id attempted - violation add failed"
            );
            return (0);
        }
    }

    # Check if the violation was open or closed
    my $was_open = 0;

    if ($existing->{status} eq 'open') {
       $was_open = 1;
    } else {
       $was_open = 0;
    }

    foreach my $item ( keys(%data) ) {
        $existing->{$item} = $data{$item};
    }

    $logger->info( "violation for mac "
            . $existing->{mac} . " vid "
            . $existing->{vid}
            . " modified" );

    # Handle the release date case on the modify (from the GUI)
    if ($data{status} eq 'closed' && $was_open && $existing->{release_date} eq '') {
        $existing->{release_date} = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time));
    } elsif ($data{status} eq 'open' && !$was_open) {
        $existing->{release_date} = "";
    }

    db_query_execute(VIOLATION, $violation_statements, 'violation_modify_sql',
        $existing->{mac},        $existing->{vid},
        $existing->{start_date}, $existing->{release_date},
        $existing->{status},     $existing->{ticket_ref},
        $existing->{notes},      $id
    ) || return (0);
    return (1);
}

sub violation_grace {
    my ( $mac, $vid ) = @_;

    my $query = db_query_execute(VIOLATION, $violation_statements, 'violation_grace_sql', $mac, $vid)
        || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    $val = 0 if ( !$val );
    return ($val);
}

sub violation_count {
    my ($mac) = @_;

    my $query = db_query_execute(VIOLATION, $violation_statements, 'violation_count_sql', $mac)
        || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

sub violation_count_trap {
    my ($mac) = @_;

    my $query = db_query_execute(VIOLATION, $violation_statements, 'violation_count_trap_sql', $mac)
        || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

sub violation_count_vid {
    my ( $mac, $vid ) = @_;
    my $query = db_query_execute(VIOLATION, $violation_statements, 'violation_count_vid_sql', $mac, $vid)
        || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

sub violation_exist {
    my ( $mac, $vid, $start_date ) = @_;

    my $query = db_query_execute(VIOLATION, $violation_statements, 'violation_exist_sql', $mac, $vid, $start_date)
        || return (0);
    my $val = $query->fetchrow_hashref();
    $query->finish();
    return ($val);
}

sub violation_exist_id {
    my ($id) = @_;
    my $query = db_query_execute(VIOLATION, $violation_statements, 'violation_exist_id_sql', $id)
        || return (0);
    my $val = $query->fetchrow_hashref();
    $query->finish();
    return ($val);
}

sub violation_exist_open {
    my ( $mac, $vid ) = @_;
    my $query = db_query_execute(VIOLATION, $violation_statements, 'violation_exist_open_sql', $mac, $vid)
        || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

sub violation_view {
    my ($id) = @_;
    return db_data(VIOLATION, $violation_statements, 'violation_view_sql', $id);
}

sub violation_count_all {
    my ( $id, %params ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # Hack! we prepare the statement here so that $node_count_all_sql is pre-filled
    violation_db_prepare() if (!$violation_db_prepared);
    my $violation_count_all_sql = $violation_statements->{'violation_count_all_sql'};

    if ( defined( $params{'where'} ) ) {
        my @where = ();
        if ( ref($params{'where'}{'between'}) ) {
            push(@where, sprintf '%s BETWEEN %s AND %s',
                 $params{'where'}{'between'}->[0],
                 get_db_handle()->quote($params{'where'}{'between'}->[1]),
                 get_db_handle()->quote($params{'where'}{'between'}->[2]));
        }
        if (@where) {
            $violation_count_all_sql .= ' WHERE ' . join(' AND ', @where);
        }
    }

    # Hack! Because of the nature of the query built here (we cannot prepare it), we construct it as a string
    # and pf::db will recognize it and prepare it as such
    $violation_statements->{'violation_count_all_sql_custom'} = $violation_count_all_sql;
    #$logger->debug($node_count_all_sql);

    return db_data(VIOLATION, $violation_statements, 'violation_count_all_sql_custom');
}

sub violation_view_all {
    return db_data(VIOLATION, $violation_statements, 'violation_view_all_sql');
}

sub violation_view_top {
    my ($mac) = @_;
    my $query = db_query_execute(VIOLATION, $violation_statements, 'violation_view_top_sql', $mac) || return (0);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}

sub violation_view_open {
    my ($mac) = @_;
    return db_data(VIOLATION, $violation_statements, 'violation_view_open_sql', $mac);
}

sub violation_view_open_desc {
    my ($mac) = @_;
    return db_data(VIOLATION, $violation_statements, 'violation_view_open_desc_sql', $mac);
}

=item violation_view_open_uniq

Returns a list of MACs which have at least one opened violation.
Since trap violations stay open, this has the intended effect of getting all MACs which should be isolated.

=cut
sub violation_view_open_uniq {
    return db_data(VIOLATION, $violation_statements, 'violation_view_open_uniq_sql');
}

sub violation_view_desc {
    my ($mac) = @_;
    return db_data(VIOLATION, $violation_statements, 'violation_view_desc_sql', $mac);
}

sub violation_view_open_all {
    return db_data(VIOLATION, $violation_statements, 'violation_view_open_all_sql');
}

sub violation_view_all_active {
    return db_data(VIOLATION, $violation_statements, 'violation_view_all_active_sql');
}

#
sub violation_add {
    my ( $mac, $vid, %data ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::violation');
    return (0) if ( !$vid );

    #print Dumper(%data);
    #defaults
    $data{start_date} = mysql_date()
        if ( !defined $data{start_date} || !$data{start_date} );
    $data{release_date} = 0 if ( !defined $data{release_date} );
    $data{status} = "open" if ( !defined $data{status} || !$data{status} );
    $data{notes}  = ""     if ( !defined $data{notes} );
    $data{ticket_ref} = "" if ( !defined $data{ticket_ref} );

    if ( violation_exist_open( $mac, $vid ) ) {
        $logger->info("violation $vid already exists for $mac, not adding again");
        return (1);
    }

    my $latest_violation = ( violation_view_open($mac) )[0];
    my $latest_vid       = $latest_violation->{'vid'};
    if ($latest_vid) {

        # don't add a hostscan if violation exists
        if ( $vid == $portscan_sid ) {
            $logger->warn(
                "hostscan detected from $mac, but violation $latest_vid exists - ignoring"
            );
            return (1);
        }

        #replace UNKNOWN hostscan with known violation
        if ( $latest_vid == $portscan_sid ) {
            $logger->info(
                "violation $vid detected for $mac - updating existing hostscan entry"
            );
            violation_force_close( $mac, $portscan_sid );
        }
    }

    # if this node doesn't exist we'll run into problems so create it
    if ( !node_exist($mac) ) {
        node_add_simple($mac);
    } else {

        # check if we are under the grace period of a previous violation
        my ($remaining_time) = violation_grace( $mac, $vid );
        if ( $remaining_time > 0 ) {
            $logger->info("$remaining_time grace remaining on violation $vid for node $mac. Not adding violation.");
            return (1);
        } else {
            $logger->info("grace expired on violation $vid for node $mac");
        }
    }

    # insert violation into db
    db_query_execute(VIOLATION, $violation_statements, 'violation_add_sql',
        $mac, $vid, $data{start_date}, $data{release_date}, $data{status}, $data{ticket_ref}, $data{notes})
        || return (0);
    $logger->info("violation $vid added for $mac");
    pf::action::action_execute( $mac, $vid, $data{notes} );
    return (1);
}

=item * violation_trigger 

Evaluates a candidate violation and if its valid, will add it to the node and trigger a VLAN change if required 
        
Returns 1 if at least one violation is added, 0 otherwise.

=cut    
sub violation_trigger {
    my ( $mac, $tid, $type, %data ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::violation');
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

    require pf::trigger;
    my @trigger_info = pf::trigger::trigger_view_enable( $tid, $type );
    if ( !scalar(@trigger_info) ) {
        $logger->debug("violation not added, no trigger found for ${type}::${tid} or violation is disabled");
        return 0;
    }

    my $addedViolation = 0;
    foreach my $row (@trigger_info) {
        # if trigger row is not an hash reference, has no vid or its vid is non numeric, we report and skip
        if (ref($row) ne 'HASH' || !defined($row->{'vid'}) || $row->{'vid'} !~ /^\d+$/) {
            $logger->warn("Invalid violation / trigger configuration. Error on trigger ${type}::${tid}");
            next;
        }
        my $vid = $row->{'vid'};

        # if the node's category is whitelisted, skip
        if (_is_node_category_whitelisted($row, $mac)) {
            $logger->info("Not adding violation ${vid} node $mac is immune because of its category");
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
        if (action_exist($vid, $pf::action::AUTOREG) && is_node_registered($mac)) {
            $logger->debug(
                "violation $vid triggered with action $pf::action::AUTOREG but node $mac is already registered. " .
                "Not adding violation."
            );
            next;
        }
        # Compute the release date
        my $date = 0;
        
        # Check if we have a window defined for the violation, and act properly 
        # TODO: Handle the "dynamic" keyword
        my $class = class_view($vid);

        if (defined($class->{'window'})) {
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

        $logger->info("calling '$bin_dir/pfcmd violation add vid=$vid,mac=$mac,release_date=$date' (trigger ${type}::${tid})");
        # running pfcmd because it will call an access re-evaluation if needed
        pf_run("$bin_dir/pfcmd \'violation add vid=$vid,mac=$mac,release_date=\"$date\"\'");
        $addedViolation = 1;
    }
    return $addedViolation;
}

sub violation_delete {
    my ($id) = @_;
    db_query_execute(VIOLATION, $violation_statements, 'violation_delete_sql', $id);
    return (0);
}

#return -1 on failure, because grace=0 is unlimited
#
sub violation_close {
    my ( $mac, $vid ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::violation');
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
        db_query_execute(VIOLATION, $violation_statements, 'violation_close_sql', $mac, $vid)
            || return (0);
        $logger->info("violation $vid closed for $mac");
        return ($grace);
    }
    return (-1);
}

# use force close to definitely shut a violation
# used for non-trap violation and to close scan violations
#
sub violation_force_close {
    my ( $mac, $vid ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::violation');

    db_query_execute(VIOLATION, $violation_statements, 'violation_close_sql', $mac, $vid)
        || return (0);
    $logger->info("violation $vid force-closed for $mac");
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

    my $query = db_query_execute(VIOLATION, $violation_statements, 'violation_exist_acct_sql', $mac, $vid, $ceil)
        || return (0);
    my $val = $query->fetchrow_hashref();
    $query->finish();
    return ($val);
}

=item * violation_view_last_closed - grab the last closed violation within the accounting interval window

=cut
sub violation_view_last_closed {
    my ( $mac, $vid ) = @_;

    return db_data(VIOLATION, $violation_statements, 'violation_last_closed_sql', $mac, $vid);
}

=item * _is_node_category_whitelisted - is a node immune to a given violation based on its category

=cut
sub _is_node_category_whitelisted {
    my ($trigger_info, $mac) = @_;
    my $logger = Log::Log4perl::get_logger('pf::violation');

    # if whitelist is empty, node is not whitelisted
    if (!defined($trigger_info->{'whitelisted_categories'}) || $trigger_info->{'whitelisted_categories'} eq '') {
        return 0;
    }

    # Grabbing the node's informations (incl. category)
    # Note: consider extracting out of here and putting in violation_trigger and passing node_info hashref instead
    my $node_info = node_attributes($mac);
    if(!defined($node_info) || ref($node_info) ne 'HASH') {
        $logger->warn("Something went wrong trying to fetch the node info");
        return 0;
    }

    # trying to match node's category on whitelisted categories
    my $category_found = 0;
    # whitelisted_categories is of the form "cat1,cat2,cat3,etc."
    foreach my $category (split(",", $trigger_info->{'whitelisted_categories'})) {
        if (lc($category) eq lc($node_info->{'category'})) {
            $category_found = 1;
        }
    }

    return $category_found;
}

=item violation_maintenance 

Check if we should close violations based on release_date

=cut
sub violation_maintenance {
    my $logger = Log::Log4perl::get_logger('pf::violation');

    $logger->debug("Looking at expired violations...");

    my $violation_query = db_query_execute(VIOLATION, $violation_statements, 'violation_release_sql') || return (0);

    while (my $row = $violation_query->fetchrow_hashref()) {
        my $currentMac = $row->{mac};
        my $currentVid = $row->{vid};
        my $result = violation_force_close($currentMac,$currentVid);
        
        # If close is a success, reevaluate the Access for the node
        if ($result) {
            pf::enforcement::reevaluate_access( $currentMac, "manage_vclose" );
        }
    };

    return (1);
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

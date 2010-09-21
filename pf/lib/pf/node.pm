package pf::node;

=head1 NAME

pf::node - module for node management.

=cut

=head1 DESCRIPTION

pf::node contains the functions necessary to manage node: creation, 
deletion, registration, expiration, read info, ...

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use Log::Log4perl;
use Log::Log4perl::Level;
use Net::MAC;

use constant NODE => 'node';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        node_db_prepare
        $node_db_prepared

        node_exist
        node_pid
        node_delete
        node_add
        node_add_simple
        node_view
        node_count_all
        node_view_all
        node_view_with_fingerprint
        node_modify
        node_register_auto
        node_register
        node_deregister
        node_unregistered
        nodes_maintenance
        nodes_unregistered
        nodes_registered
        nodes_registered_not_violators
        nodes_active_unregistered
        node_expire_lastarp
        node_cleanup
        node_update_lastarp
        node_mac_wakeup
    );
}

use pf::config;
use pf::db;
use pf::nodecategory;
use pf::util;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $node_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $node_statements = {};

=head1 SUBROUTINES

TODO: This list is incomlete

=over

=cut

sub node_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::node');
    $logger->debug("Preparing pf::node database queries");

    $node_statements->{'node_exist_sql'} = get_db_handle()->prepare(qq[ select mac from node where mac=? ]);

    $node_statements->{'node_pid_sql'} = get_db_handle()->prepare(qq[ select count(*) from node where status='reg' and pid=? ]);

    $node_statements->{'node_add_sql'} = get_db_handle()->prepare(
        qq[ insert into node(mac,pid,category_id,detect_date,regdate,unregdate,lastskip,status,user_agent,computername,notes,dhcp_fingerprint,last_arp,last_dhcp,switch,port,vlan) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ]);

    $node_statements->{'node_delete_sql'} = get_db_handle()->prepare(qq[ delete from node where mac=? ]);

    $node_statements->{'node_modify_sql'} = get_db_handle()->prepare(
        qq[ update node set mac=?,pid=?,category_id=?,detect_date=?,regdate=?,unregdate=?,lastskip=?,status=?,user_agent=?,computername=?,notes=?,dhcp_fingerprint=?,last_arp=?,last_dhcp=?,switch=?,port=?,vlan=? where mac=? ]);

    $node_statements->{'node_view_sql'} = get_db_handle()->prepare(
        qq[ SELECT node.mac,node.pid,IF(ISNULL(node_category.name),'',node_category.name) as category,node.detect_date,node.regdate,node.unregdate,node.lastskip,node.status,node.user_agent,node.computername,node.notes,node.last_arp,node.last_dhcp,node.dhcp_fingerprint,node.switch,node.port,node.vlan,count(violation.mac) as nbopenviolations FROM node LEFT JOIN node_category USING (category_id) LEFT JOIN violation on node.mac=violation.mac AND violation.status='open' WHERE node.mac=? GROUP BY node.mac ]);

    $node_statements->{'node_view_with_fingerprint_sql'} = get_db_handle()->prepare(
        qq[ SELECT mac,pid,IF(ISNULL(node_category.name),'',node_category.name) as category,detect_date,regdate,unregdate,lastskip,status,user_agent,computername,node.notes,last_arp,last_dhcp,ifnull(os_class.description, ' ') as dhcp_fingerprint,switch,port,vlan FROM node LEFT JOIN node_category USING (category_id) LEFT JOIN dhcp_fingerprint ON node.dhcp_fingerprint=dhcp_fingerprint.fingerprint LEFT JOIN os_mapping ON dhcp_fingerprint.os_id=os_mapping.os_type LEFT JOIN os_class ON os_mapping.os_class=os_class.class_id where mac=? ]);

    # This guy here is special, have a look in node_view_all to see why
    $node_statements->{'node_view_all_sql'}
        = "SELECT node.mac,node.pid,IF(ISNULL(node_category.name),'',node_category.name) as category,node.detect_date,node.regdate,node.unregdate,node.lastskip,node.status,node.user_agent,node.computername,node.notes,node.last_arp,node.last_dhcp,node.dhcp_fingerprint,node.switch,node.port,node.vlan,count(violation.mac) as nbopenviolations FROM node LEFT JOIN node_category USING (category_id) LEFT JOIN violation ON node.mac=violation.mac AND violation.status='open' GROUP BY node.mac";

    # This guy here is special, have a look in node_count_all to see why
    $node_statements->{'node_count_all_sql'} = "select count(*) as nb from node";

    $node_statements->{'node_ungrace_sql'} = get_db_handle()->prepare(
        qq [ select mac from node where status="grace" and unix_timestamp(now())-unix_timestamp(lastskip) > ]
            . $Config{'registration'}{'skip_reminder'} );

    $node_statements->{'node_expire_unreg_field_sql'} = get_db_handle()->prepare(
        qq [ select mac from node where status="reg" and unregdate != 0 and unregdate < now() ]);

    $node_statements->{'node_expire_window_sql'} = get_db_handle()->prepare(
        qq [ select mac from node where status="reg" and unix_timestamp(regdate) + ]
            . $Config{'registration'}{'expire_window'}
            . qq[ < unix_timestamp(now()) ] );

    $node_statements->{'node_expire_deadline_sql'} = get_db_handle()->prepare(
        qq [ select mac from node where status="reg" and regdate < ]
            . $Config{'registration'}{'expire_deadline'} );

    $node_statements->{'node_expire_session_sql'} = get_db_handle()->prepare(
        qq [ update node n set n.status="unreg" where n.status="reg" and n.mac not in (select i.mac from iplog i where (i.end_time=0 or i.end_time > now())) and n.mac not in (select i.mac from iplog i where end_time!=0 and unix_timestamp(now())-unix_timestamp(i.end_time) < ] . $Config{'registration'}{'expire_session'} );

    $node_statements->{'node_expire_lastarp_sql'} = get_db_handle()->prepare(
        qq [ select mac from node where unix_timestamp(last_arp) < (unix_timestamp(now()) - ?) and last_arp!=0 ]);

    $node_statements->{'node_unregistered_sql'} = get_db_handle()->prepare(
        qq [ select mac,pid,detect_date,regdate,unregdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,dhcp_fingerprint,switch,port,vlan from node where status="unreg" and mac=? ]);

    $node_statements->{'nodes_unregistered_sql'} = get_db_handle()->prepare(
        qq [ select mac,pid,detect_date,regdate,unregdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,dhcp_fingerprint,switch,port,vlan from node where status="unreg" ]);

    $node_statements->{'nodes_registered_sql'} = get_db_handle()->prepare(
        qq [ select mac,pid,detect_date,regdate,unregdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,dhcp_fingerprint,switch,port,vlan from node where status="reg" ]);

    $node_statements->{'nodes_registered_not_violators_sql'} = get_db_handle()->prepare(
        qq [ select node.mac from node left join violation on node.mac=violation.mac and violation.status='open' where node.status='reg' group by node.mac having count(violation.mac)=0 ]);

    $node_statements->{'nodes_active_unregistered_sql'} = get_db_handle()->prepare(
        qq [ select n.mac,n.pid,n.detect_date,n.regdate,n.unregdate,n.lastskip,n.status,n.user_agent,n.computername,n.notes,i.ip,i.start_time,i.end_time,n.last_arp from node n left join iplog i on n.mac=i.mac where n.status="unreg" and (i.end_time=0 or i.end_time > now()) ]);

    $node_statements->{'nodes_active_sql'} = get_db_handle()->prepare(
        qq [ select n.mac,n.pid,n.detect_date,n.regdate,n.unregdate,n.lastskip,n.status,n.user_agent,n.computername,n.notes,n.dhcp_fingerprint,i.ip,i.start_time,i.end_time,n.last_arp from node n, iplog i where n.mac=i.mac and (i.end_time=0 or i.end_time > now()) ]);

    $node_statements->{'node_update_lastarp_sql'} = get_db_handle()->prepare(qq [ update node set last_arp=now() where mac=? ]);

    $node_db_prepared = 1;
    return 1;
}

#
# return mac if the node exists
#
sub node_exist {
    my ($mac) = @_;
    my $query = db_query_execute(NODE, $node_statements, 'node_exist_sql', $mac) || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

#
# return number of nodes match that PID
#
sub node_pid {
    my ($pid) = @_;
    my $query = db_query_execute(NODE, $node_statements, 'node_pid_sql', $pid) || return (0);
    my ($count) = $query->fetchrow_array();
    $query->finish();
    return ($count);
}

#
# delete and return 1
#
sub node_delete {
    my ($mac) = @_;
    my $logger = Log::Log4perl::get_logger('pf::node');
    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();
    if ( !node_exist($mac) ) {
        $logger->error("delete of non-existent node '$mac' failed");
        return 0;
    }
    if ( lc($Config{'network'}{'mode'}) eq 'vlan' ) {
        require pf::locationlog;
        if ( defined( pf::locationlog::locationlog_view_open_mac($mac) ) ) {
            $logger->warn(
                "VLAN isolation mode enabled and $mac has open locationlog entry. Node deletion prohibited"
            );
            return 0;
        }
    }
    db_query_execute(NODE, $node_statements, 'node_delete_sql', $mac) || return (0);
    $logger->info("node $mac deleted");
    return (1);
}

#
# clean input parameters and add to node table
#
sub node_add {
    my ( $mac, %data ) = @_;

    my $logger = Log::Log4perl::get_logger('pf::node');
    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();
    $mac = lc($mac);
    return (0) if ( !valid_mac($mac) );

    if ( node_exist($mac) ) {
        $logger->warn("attempt to add existing node $mac");

        #return node_modify($mac,%data);
        return (2);
    }

    #foreach my $row (node_desc()){
    #    $data{$row->{'Field'}}="" if (!defined $data{$row->{'Field'}});
    #}

    foreach my $field (
        'pid',      'detect_date',      'regdate',    'unregdate',
        'lastskip', 'status',           'user_agent', 'computername',
        'notes',    'dhcp_fingerprint', 'last_arp',   'last_dhcp', 
        'switch',   'port',             'vlan'
        )
    {
        $data{$field} = "" if ( !defined $data{$field} );
    }
    if ( ( $data{status} eq 'reg' ) && ( $data{regdate} eq '' ) ) {
        $data{regdate} = mysql_date();
    }

    # category handling
    $data{'category_id'} = _node_category_handling(%data);
    if (defined($data{'category_id'}) && $data{'category_id'} == 0) {
        $logger->error("Unable to insert node because specified category doesn't exist");
        return (0);
    }

    db_query_execute(NODE, $node_statements, 'node_add_sql',
        $mac, $data{pid}, $data{category_id}, $data{detect_date}, $data{regdate}, $data{unregdate}, $data{lastskip},
        $data{status}, $data{user_agent}, $data{computername}, $data{notes}, $data{dhcp_fingerprint}, $data{last_arp},
        $data{last_dhcp}, $data{switch}, $data{port}, $data{vlan}
    ) || return (0);
    return (1);
}

#
# simple wrapper for pfmon/pfdhcplistener-detected and auto-generated nodes
#
sub node_add_simple {
    my ($mac) = @_;
    my $date  = mysql_date();
    my %tmp   = (
        'pid'         => 1,
        'detect_date' => $date,
        'regdate'     => 0,
        'unregdate'   => 0,
        'last_skip'   => 0,
        'status'      => 'unreg',
        'last_dhcp'   => 0
    );
    if ( !node_add( $mac, %tmp ) ) {
        return (0);
    } else {
        return (1);
    }
}

#
# return row = mac
#
sub node_view {
    my ($mac) = @_;

    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();
    my $query = db_query_execute(NODE, $node_statements, 'node_view_sql', $mac) || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

sub node_count_all {
    my ( $id, %params ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::node');

    # Hack! we prepare the statement here so that $node_view_all_sql is pre-filled
    node_db_prepare() if (!$node_db_prepared);
    my $node_count_all_sql = $node_statements->{'node_count_all_sql'};

    if ( defined( $params{'where'} ) ) {
        if ( $params{'where'}{'type'} eq 'pid' ) {
            $node_count_all_sql
                .= " WHERE node.pid='" . $params{'where'}{'value'} . "'";
        } elsif ( $params{'where'}{'type'} eq 'category' ) {

            my $cat_id = nodecategory_lookup($params{'where'}{'value'});
            if (!defined($cat_id)) {
                # lets be nice and issue a warning if the category doesn't exist
                $logger->warn("there was a problem looking up category ".$params{'where'}{'value'});
                # put cat_id to 0 so it'll return 0 results (achieving the count ok)
                $cat_id = 0;
            }
            $node_count_all_sql .= " WHERE category_id =" . $cat_id;
        }
    }

    # Hack! Because of the nature of the query built here (we cannot prepare it), we construct it as a string
    # and pf::db will recognize it and prepare it as such
    $node_statements->{'node_count_all_sql_custom'} = $node_count_all_sql;
    return db_data(NODE, $node_statements, 'node_count_all_sql_custom');
}

=item * node_view_all

=cut
sub node_view_all {
    my ( $id, %params ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::node');

    # Hack! we prepare the statement here so that $node_view_all_sql is pre-filled
    node_db_prepare() if (!$node_db_prepared);
    my $node_view_all_sql = $node_statements->{'node_view_all_sql'};

    if ( defined( $params{'where'} ) ) {
        if ( $params{'where'}{'type'} eq 'pid' ) {
            $node_view_all_sql
                .= " HAVING node.pid='" . $params{'where'}{'value'} . "'";

        } elsif ( $params{'where'}{'type'} eq 'category' ) {

            if (!nodecategory_lookup($params{'where'}{'value'})) {
                # lets be nice and issue a warning if the category doesn't exist
                $logger->warn("there was a problem looking up category ".$params{'where'}{'value'});
            }
            $node_view_all_sql .= " HAVING category='" . $params{'where'}{'value'} . "'";

        }
    }
    if ( defined( $params{'orderby'} ) ) {
        $node_view_all_sql .= " " . $params{'orderby'};
    }
    if ( defined( $params{'limit'} ) ) {
        $node_view_all_sql .= " " . $params{'limit'};
    }

    # Hack! Because of the nature of the query built here (we cannot prepare it), we construct it as a string
    # and pf::db will recognize it and prepare it as such
    $node_statements->{'node_view_all_sql_custom'} = $node_view_all_sql;
    return db_data(NODE, $node_statements, 'node_view_all_sql_custom');
}

sub node_view_with_fingerprint {
    my ($mac) = @_;
    my $query = db_query_execute(NODE, $node_statements, 'node_view_with_fingerprint_sql', $mac) || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

sub node_modify {
    my ( $mac, %data ) = @_;

    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();
    my $logger = Log::Log4perl::get_logger('pf::node');
    $mac = lc($mac);
    return (0) if ( !valid_mac($mac) );

    if ( !node_exist($mac) ) {
        if ( node_add_simple($mac) ) {
            $logger->info(
                "modify of non-existent node $mac attempted - node added");
        } else {
            $logger->error(
                "modify of non-existent node $mac attempted - node add failed"
            );
            return (0);
        }
    }

    my $existing   = node_view($mac);
    # keep track of status
    my $old_status = $existing->{status};
    # special handling for category to category_id conversion
    $existing->{'category_id'} = nodecategory_lookup($existing->{'category'});
    foreach my $item ( keys(%data) ) {
        $existing->{$item} = $data{$item};
    }

    # category handling 
    # if category was updated, resolve it correctly
    if (defined($data{'category'}) || defined($data{'category_id'})) {
       $existing->{'category_id'} = _node_category_handling(%data);
       if (defined($existing->{'category_id'}) && $existing->{'category_id'} == 0) {
           $logger->error("Unable to modify node because specified category doesn't exist");
           return (0);
       }   
       # once the category conversion is complete, I delete the category entry to avoid complicating things
       delete $existing->{'category'} if defined($existing->{'category'});
    }

    my $new_mac    = lc( $existing->{'mac'} );
    my $new_status = $existing->{'status'};

    if ( $mac ne $new_mac && node_exist($new_mac) ) {
        $logger->error(
            "modify of node $mac to $new_mac conflicts with existing node");
        return (0);
    }

    if (( $existing->{status} eq 'reg' )
        && (   $existing->{regdate} eq '0000-00-00 00:00:00'
            || $existing->{regdate} eq '' )
        )
    {
        $existing->{regdate} = mysql_date();
    }

    if (   ( $new_status eq 'reg' )
        && ( $old_status ne 'reg' )
        && (   $existing->{unregdate} eq '0000-00-00 00:00:00'
            || $existing->{unregdate} eq '' )
        )
    {
        $logger->debug(
            "changed registration status for mac $new_mac from $old_status to $new_status; unregdate has not been specified -> calculating it now"
        );
        my $expire_mode = $Config{'registration'}{'expire_mode'};
        if (   ( lc($expire_mode) eq 'window' )
            && ( $Config{'registration'}{'expire_window'} > 0 ) )
        {
            $existing->{'unregdate'} = POSIX::strftime(
                "%Y-%m-%d %H:%M:%S",
                localtime( time + $Config{'registration'}{'expire_window'} )
            );
        } elsif (  ( lc($expire_mode) eq 'deadline' )
            && ( $Config{'registration'}{'expire_deadline'} - time > 0 ) )
        {
            $existing->{'unregdate'} = POSIX::strftime( "%Y-%m-%d %H:%M:%S",
                localtime( $Config{'registration'}{'expire_deadline'} ) );
        }
    }

    db_query_execute(NODE, $node_statements, 'node_modify_sql',
        $new_mac, $existing->{pid}, $existing->{category_id}, $existing->{detect_date}, $existing->{regdate},
        $existing->{unregdate}, $existing->{lastskip}, $existing->{status}, $existing->{user_agent},
        $existing->{computername}, $existing->{notes}, $existing->{dhcp_fingerprint}, $existing->{last_arp},
        $existing->{last_dhcp}, $existing->{switch}, $existing->{port}, $existing->{vlan}, $mac
    ) || return (0);

    return (1);
}

sub node_register_auto {
    my ($mac) = @_;
    my %tmp;
    $tmp{'user_agent'} = "AUTOREGISTERED " . mysql_date();
    $tmp{'force'}      = 1;
    return node_register( $mac, $default_pid, %tmp );
}

sub node_register {
    my ( $mac, $pid, %info ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::node');
    require pf::person;
    require pf::violation;
    $mac = lc($mac);
    my $auto_registered = 0;

    if ( defined( $info{'force'} ) ) {
        $auto_registered = 1;
        delete( $info{'force'} );
    }

    my $max_nodes = 0;
    $max_nodes = $Config{'registration'}{'maxnodes'}
        if ( defined $Config{'registration'}{'maxnodes'} );
    my $owned_nodes = pf::person::person_nodes($pid);
    if ( $max_nodes != 0 && $pid ne '1' && $owned_nodes >= $max_nodes ) {
        $logger->error(
            "maxnodes met or exceeded - registration of $mac to $pid failed");
        return (0);
    }

    if ( !pf::person::person_exist($pid) ) {
        $logger->info("creating person $pid");
        pf::person::person_add($pid);
    } else {
        $logger->info("person $pid already exists");
    }
    $info{'pid'}     = $pid;
    $info{'status'}  = 'reg';
    $info{'regdate'} = mysql_date();

    if ( ( !$info{'unregdate'} ) || ( !valid_date( $info{'unregdate'} ) ) ) {
        my $expire_mode = $Config{'registration'}{'expire_mode'};
        if (   ( lc($expire_mode) eq 'window' )
            && ( $Config{'registration'}{'expire_window'} > 0 ) )
        {
            $info{'unregdate'} = POSIX::strftime(
                "%Y-%m-%d %H:%M:%S",
                localtime( time + $Config{'registration'}{'expire_window'} )
            );
        } elsif (  ( lc($expire_mode) eq 'deadline' )
            && ( $Config{'registration'}{'expire_deadline'} - time > 0 ) )
        {
            $info{'unregdate'} = POSIX::strftime( "%Y-%m-%d %H:%M:%S",
                localtime( $Config{'registration'}{'expire_deadline'} ) );
        }
    }

    if ( lc($Config{'network'}{'mode'})  eq 'vlan' ) {
        if ( !defined( $info{'vlan'} ) ) {
            require Config::IniFiles;
            my %ConfigVlan;
            tie %ConfigVlan, 'Config::IniFiles',
                ( -file => "$conf_dir/switches.conf" );
            my @errors = @Config::IniFiles::errors;
            if ( scalar(@errors) ) {
                $logger->error( "Error reading switches.conf: " 
                                . join( "\n", @errors ) .  "\n" );
            } else {
                $info{'vlan'} = $ConfigVlan{'default'}{'normalVlan'};
                $logger->info( "auto-configured VLAN to " . $info{'vlan'} );
            }
        }
    }

    if ( !node_modify( $mac, %info ) ) {
        $logger->error("modify of node $mac failed");
        return (0);
    }

    if ( !( lc($Config{'network'}{'mode'}) eq 'vlan' ) ) {
        require pf::iptables;
        if ( !pf::iptables::iptables_mark_node( $mac, $reg_mark ) ) {
            $logger->error("unable to mark node $mac as registered");
            return (0);
        }
    }

    if ( !$auto_registered ) {

        #nessus code
        if ( isenabled( $Config{'scan'}{'registration'} ) ) {
            pf::violation::violation_add( $mac, 1200001 );
        }

    }

    return (1);
}

sub node_deregister {
    my ($mac) = @_;
    my $logger = Log::Log4perl::get_logger('pf::node');
    my %info;
    $info{'status'}    = 'unreg';
    $info{'regdate'}   = 0;
    $info{'unregdate'} = 0;
    $info{'lastskip'}  = 0;
    $info{'pid'}       = 1;

    if ( !node_modify( $mac, %info ) ) {
        $logger->error("unable to de-register node $mac");
        return (0);
    }

    if ( !( lc($Config{'network'}{'mode'}) eq 'vlan' ) ) {
        require pf::iptables;
        if ( !pf::iptables::iptables_unmark_node( $mac, $reg_mark ) ) {
            $logger->error("unable to delete registration rule for $mac: $!");
            return (0);
        }
    }

    # we need to rely on the cgi's to do this work
    # now that they are not SUID
    #return(trapmac($mac)) if ($Config{'network'}{'mode'} =~ /arp/i);
}

=item * nodes_maintenance - handling deregistration on node expiration and node grace 

called by pfmon daemon every 10 maintenance interval (usually each 10 minutes)

=cut
sub nodes_maintenance {
    my $logger = Log::Log4perl::get_logger('pf::node');

    my $expire_mode = $Config{'registration'}{'expire_mode'};
    $logger->debug("nodes_maintenance called with expire_mode=$expire_mode");

    my $ungrace_query = db_query_execute(NODE, $node_statements, 'node_ungrace_sql') || return (0);
    while (my $row = $ungrace_query->fetchrow_hashref()) {
        my $currentMac = $row->{mac};
        `/usr/local/pf/bin/pfcmd manage deregister $currentMac`;
        $logger->info("modified $currentMac from status 'grace' to 'unreg'" );
    };

    if ( isdisabled($expire_mode) ) {
        return (1);
    } else {
        my $expire_unreg_query = db_query_execute(NODE, $node_statements, 'node_expire_unreg_field_sql')
            || return (0);
        while (my $row = $expire_unreg_query->fetchrow_hashref()) {
            my $currentMac = $row->{mac};
            `/usr/local/pf/bin/pfcmd manage deregister $currentMac`;
            $logger->info("modified $currentMac from status 'reg' to 'unreg' based on unregdate colum" );
        };

        if (  ( lc($expire_mode) eq 'window' )
            && $Config{'registration'}{'expire_window'} > 0 )
        {
            my $expire_window_query = db_query_execute(NODE, $node_statements, 'node_expire_window_sql') || return (0);
            while (my $row = $expire_window_query->fetchrow_hashref()) {
                my $currentMac = $row->{mac};
                `/usr/local/pf/bin/pfcmd manage deregister $currentMac`;
                $logger->info("modified $currentMac from status 'reg' to 'unreg' based on expiration window" );
            };

        } elsif ((lc($expire_mode) eq 'deadline' ) && ( time - $Config{'registration'}{'expire_deadline'} > 0 )) {
            my $expire_deadline_query = db_query_execute(NODE, $node_statements, 'node_expire_deadline_sql') 
                || return (0);
            while (my $row = $expire_deadline_query->fetchrow_hashref()) {
                my $currentMac = $row->{mac};
                `/usr/local/pf/bin/pfcmd manage deregister $currentMac`;
                $logger->info("modified $currentMac from status 'reg' to 'unreg' based on expiration deadline" );
            };

        } elsif ( ( lc($expire_mode) eq 'session' ) 
            &&  !( $Config{'network'}{'mode'} =~ /vlan/i ) )
        {
            my $expire_session_query = db_query_execute(NODE, $node_statements, 'node_expire_session_sql') 
                || return (0);
            my $rows = $expire_session_query->rows;
            $logger->log(
                ( ( $rows > 0 ) ? $INFO : $DEBUG ),
                "modified $rows nodes from status 'reg' to 'unreg' based on session expiration"
            );
        }
    }
    return (1);
}

# check to see is $mac is registered
#
sub node_unregistered {
    my ($mac) = @_;

    my $query = db_query_execute(NODE, $node_statements, 'node_unregistered_sql', $mac) || return (0);
    my $ref = $query->fetchrow_hashref();
    $query->finish();
    return ($ref);
}

sub nodes_unregistered {
    return db_data(NODE, $node_statements, 'nodes_unregistered_sql');
}

sub nodes_registered {
    return db_data(NODE, $node_statements, 'nodes_registered_sql');
}

sub nodes_registered_not_violators {
    return db_data(NODE, $node_statements, 'nodes_registered_not_violators_sql');
}

sub nodes_active_unregistered {
    return db_data(NODE, $node_statements, 'nodes_active_unregistered_sql');
}

sub node_expire_lastarp {
    my ($time) = @_;
    return db_data(NODE, $node_statements, 'node_expire_lastarp_sql', $time);
}

sub node_cleanup {
    my ($time) = @_;
    my $logger = Log::Log4perl::get_logger('pf::node');
    $logger->debug("calling node_cleanup with time=$time");
    foreach my $row ( node_expire_lastarp($time) ) {
        my $mac = $row->{'mac'};
        $logger->info("mac $mac not seen for $time seconds, deleting");
        node_delete( $row->{'mac'} );
    }
    return (0);
}

sub node_update_lastarp {
    my ($mac) = @_;
    db_query_execute(NODE, $node_statements, 'node_update_lastarp_sql', $mac) || return (0);
    return (1);
}

=item * node_mac_wakeup

Sub invoked each time a MAC as activity (eiher from dhcp or traps).

in: mac address

out: void

=cut

sub node_mac_wakeup {
    my ($mac) = @_;
    my $logger = Log::Log4perl::get_logger('pf::node');

    # Is there a violation for the Vendor of this MAC?
    require pf::violation;
    my $dec_oui = get_decimal_oui_from_mac($mac);
    $logger->debug( "sending MAC::$dec_oui ($mac) trigger" );
    pf::violation::violation_trigger( $mac, $dec_oui, "VENDORMAC" );
}


=item * node_category_handling - assigns category_id based on provided data

expects category_id or category name in the form of category => 'name' or category_id => id

returns category_id, undef if no category was required or 0 if no category is found (which is a problem)

=cut
sub _node_category_handling {
    my (%data) = @_;
    my $logger = Log::Log4perl::get_logger('pf::node');

    if (defined($data{'category_id'})) {
        # category_id has priority over category
        if (!nodecategory_exist($data{'category_id'})) {
            $logger->debug("Unable to insert node because specified category doesn't exist: ".$data{'category_id'});
            return 0; 
        }

    # web node add will always push category="" so we need to explicitly ignore it
    } elsif (defined($data{'category'}) && $data{'category'} ne '')  {

        # category name into id conversion
        $data{'category_id'} = nodecategory_lookup($data{'category'});
        if (!defined($data{'category_id'}))  {
            $logger->debug("Unable to insert node because specified category doesn't exist: ".$data{'category'});
            return 0;
        }

    } else {
        # if no category is specified then we set to undef so that DBI will insert a NULL
        $data{'category_id'} = undef;
    }
    return $data{'category_id'};
}

=back

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

Maikel van der Roest <mvdroest@utelisys.com>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2007-2010 Inverse inc.

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

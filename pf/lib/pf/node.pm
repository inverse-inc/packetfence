package pf::node;

=head1 NAME

pf::node

=cut

use strict;
use warnings;
use Log::Log4perl;
use Log::Log4perl::Level;
use Net::MAC;

our (
    $node_modify_sql,          $node_exist_sql,
    $node_pid_sql,             $node_delete_sql,
    $node_add_sql,             $node_regdate_sql,
    $node_view_sql,            $node_count_all_sql,
    $node_view_all_sql,        $node_view_with_fingerprint_sql,
    $node_ungrace_sql,         $node_expire_window_sql,
    $node_expire_deadline_sql, $node_expire_unreg_field_sql,
    $node_expire_session_sql,  $node_expire_lastarp_sql,
    $node_unregistered_sql,    $nodes_unregistered_sql,
    $node_update_lastarp_sql,  $nodes_active_unregistered_sql,
    $nodes_registered_sql,     $nodes_registered_not_violators_sql,
    $nodes_active_sql,         $node_cleanup_sql,
    $is_node_db_prepared
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT
        = qw(node_db_prepare node_exist node_pid node_delete node_add node_add_simple node_view node_count_all node_view_all node_view_with_fingerprint
        node_modify node_register_auto node_register node_deregister nodes_maintenance node_unregistered
        nodes_unregistered nodes_registered nodes_registered_not_violators nodes_active_unregistered
        node_expire_lastarp node_cleanup node_update_lastarp);
}

use pf::config;
use pf::db;
use pf::util;

$is_node_db_prepared = 0;

#node_db_prepare($dbh) if (!$thread);

sub node_db_prepare {
    my ($dbh) = @_;
    db_connect($dbh);
    my $logger = Log::Log4perl::get_logger('pf::node');
    $logger->debug("Preparing pf::node database queries");
    $node_exist_sql = $dbh->prepare(qq[ select mac from node where mac=? ]);
    $node_pid_sql   = $dbh->prepare(
        qq[ select count(*) from node where status='reg' and pid=? ]);
    $node_add_sql
        = $dbh->prepare(
        qq[ insert into node(mac,pid,detect_date,regdate,unregdate,lastskip,status,user_agent,computername,notes,dhcp_fingerprint,last_dhcp,switch,port,vlan) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ]
        );
    $node_delete_sql = $dbh->prepare(qq[ delete from node where mac=? ]);
    $node_modify_sql
        = $dbh->prepare(
        qq[ update node set mac=?,pid=?,detect_date=?,regdate=?,unregdate=?,lastskip=?,status=?,user_agent=?,computername=?,notes=?,dhcp_fingerprint=?,last_dhcp=?,switch=?,port=?,vlan=? where mac=? ]
        );
    $node_view_sql
        = $dbh->prepare(
        qq[ select node.mac,node.pid,node.detect_date,node.regdate,node.unregdate,node.lastskip,node.status,node.user_agent,node.computername,node.notes,node.last_arp,node.last_dhcp,node.dhcp_fingerprint,node.switch,node.port,node.vlan,ifnull(openviolations.nb,0) as nbopenviolations from node left join (select violation.mac,count(*) as nb from violation where status='open' group by violation.mac) as openviolations on node.mac=openviolations.mac where node.mac=? ]
        );
    $node_view_with_fingerprint_sql
        = $dbh->prepare(
        qq[ select mac,pid,detect_date,regdate,unregdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,ifnull(os_class.description, ' ') as dhcp_fingerprint,switch,port,vlan from node left join dhcp_fingerprint ON node.dhcp_fingerprint=dhcp_fingerprint.fingerprint LEFT JOIN os_mapping ON dhcp_fingerprint.os_id=os_mapping.os_type LEFT JOIN os_class ON os_mapping.os_class=os_class.class_id where mac=? ]
        );
    $node_view_all_sql
        = "select node.mac,node.pid,node.detect_date,node.regdate,node.unregdate,node.lastskip,node.status,node.user_agent,node.computername,node.notes,node.last_arp,node.last_dhcp,node.dhcp_fingerprint,node.switch,node.port,node.vlan,ifnull(openviolations.nb,0) as nbopenviolations from node left join (select violation.mac,count(*) as nb from violation where status='open' group by violation.mac) as openviolations on node.mac=openviolations.mac";
    $node_count_all_sql = "select count(*) as nb from node";
    $node_ungrace_sql
        = $dbh->prepare(
        qq [ update node set status="unreg" where status="grace" and unix_timestamp(now())-unix_timestamp(lastskip) > ]
            . $Config{'registration'}{'skip_reminder'} );
    $node_expire_unreg_field_sql
        = $dbh->prepare(
        qq [ update node set status="unreg" where status="reg" and unregdate != 0 and unregdate < now() ]
        );
    $node_expire_window_sql
        = $dbh->prepare(
        qq [ update node set status="unreg" where status="reg" and unix_timestamp(regdate) + ]
            . $Config{'registration'}{'expire_window'}
            . qq[ < unix_timestamp(now()) ] );
    $node_expire_deadline_sql
        = $dbh->prepare(
        qq [ update node set status="unreg" where status="reg" and regdate < ]
            . $Config{'registration'}{'expire_deadline'} );
    $node_expire_session_sql
        = $dbh->prepare(
        qq [ update node n set n.status="unreg" where n.status="reg" and n.mac not in (select i.mac from iplog i where (i.end_time=0 or i.end_time > now())) and n.mac not in (select i.mac from iplog i where end_time!=0 and unix_timestamp(now())-unix_timestamp(i.end_time) < ]
            . $Config{'registration'}{'expire_session'} );
    $node_expire_lastarp_sql
        = $dbh->prepare(
        qq [ select mac from node where unix_timestamp(last_arp) < (unix_timestamp(now()) - ?) and last_arp!=0 ]
        );
    $node_unregistered_sql
        = $dbh->prepare(
        qq [ select mac,pid,detect_date,regdate,unregdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,dhcp_fingerprint,switch,port,vlan from node where status="unreg" and mac=? ]
        );
    $nodes_unregistered_sql
        = $dbh->prepare(
        qq [ select mac,pid,detect_date,regdate,unregdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,dhcp_fingerprint,switch,port,vlan from node where status="unreg" ]
        );
    $nodes_registered_sql
        = $dbh->prepare(
        qq [ select mac,pid,detect_date,regdate,unregdate,lastskip,status,user_agent,computername,notes,last_arp,last_dhcp,dhcp_fingerprint,switch,port,vlan from node where status="reg" ]
        );
    $nodes_registered_not_violators_sql
        = $dbh->prepare(
        qq [ select mac from node where status="reg" and mac not in (select mac from violation where status="open" group by mac) ]
        );
    $nodes_active_unregistered_sql
        = $dbh->prepare(
        qq [ select n.mac,n.pid,n.detect_date,n.regdate,n.unregdate,n.lastskip,n.status,n.user_agent,n.computername,n.notes,i.ip,i.start_time,i.end_time,n.last_arp from node n left join iplog i on n.mac=i.mac where n.status="unreg" and (i.end_time=0 or i.end_time > now()) ]
        );
    $nodes_active_sql
        = $dbh->prepare(
        qq [ select n.mac,n.pid,n.detect_date,n.regdate,n.unregdate,n.lastskip,n.status,n.user_agent,n.computername,n.notes,n.dhcp_fingerprint,i.ip,i.start_time,i.end_time,n.last_arp from node n, iplog i where n.mac=i.mac and (i.end_time=0 or i.end_time > now()) ]
        );
    $node_update_lastarp_sql
        = $dbh->prepare(qq [ update node set last_arp=now() where mac=? ]);

#$node_lookup_person_sql = $dbh->prepare( qq [ select mac,pid,description,user_agent,computername from node where pid=? ] );
#$node_lookup_node_sql = $dbh->prepare( qq [ select mac,pid,description,user_agent,computername from node where mac=? ] );
    $is_node_db_prepared = 1;
    return 1;
}

#
# return mac if the node exists
#
sub node_exist {
    my ($mac) = @_;
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    $node_exist_sql->execute($mac) || return (0);
    my ($val) = $node_exist_sql->fetchrow_array();
    $node_exist_sql->finish();
    return ($val);
}

#
# return number of nodes match that PID
#
sub node_pid {
    my ($pid) = @_;
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    $node_pid_sql->execute($pid) || return (0);
    my ($count) = $node_pid_sql->fetchrow_array();
    $node_pid_sql->finish();
    return ($count);
}

#
# delete and return 1
#
sub node_delete {
    my ($mac) = @_;
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
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
    $node_delete_sql->execute($mac) || return (0);
    $logger->info("node $mac deleted");
    return (1);
}

#
# clean input parameters and add to node table
#
sub node_add {
    my ( $mac, %data ) = @_;
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
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
        'notes',    'dhcp_fingerprint', 'last_dhcp',  'switch',
        'port',     'vlan'
        )
    {
        $data{$field} = "" if ( !defined $data{$field} );
    }
    if ( ( $data{status} eq 'reg' ) && ( $data{regdate} eq '' ) ) {
        $data{regdate} = mysql_date();
    }

    $node_add_sql->execute(
        $mac,           $data{pid},              $data{detect_date},
        $data{regdate}, $data{unregdate},        $data{lastskip},
        $data{status},  $data{user_agent},       $data{computername},
        $data{notes},   $data{dhcp_fingerprint}, $data{last_dhcp},
        $data{switch},  $data{port},             $data{vlan}
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
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    my $tmpMAC = Net::MAC->new( 'mac' => $mac );
    $mac = $tmpMAC->as_IEEE();
    $node_view_sql->execute($mac) || return (0);
    my $ref = $node_view_sql->fetchrow_hashref();

    # just get one row and finish
    $node_view_sql->finish();
    return ($ref);
}

sub node_count_all {
    my ( $id, %params ) = @_;
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    if ( defined( $params{'where'} ) ) {
        if ( $params{'where'}{'type'} eq 'pid' ) {
            $node_count_all_sql
                .= " WHERE node.pid='" . $params{'where'}{'value'} . "'";
        } elsif ( $params{'where'}{'type'} eq 'category' ) {
            require pf::nodecategory;
            my $cat      = $params{'where'}{'value'};
            my @catArray = pf::nodecategory::nodecategory_view($cat);
            if ( scalar(@catArray) == 1 ) {
                my $sqlWhere = $catArray[0]->{'sql'};
                $node_count_all_sql .= " WHERE " . $sqlWhere;
            }
        }
    }
    my $node_count_all_sth = $dbh->prepare($node_count_all_sql);
    return db_data($node_count_all_sth);
}

sub node_view_all {
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    my ( $id, %params ) = @_;
    if ( defined( $params{'where'} ) ) {
        if ( $params{'where'}{'type'} eq 'pid' ) {
            $node_view_all_sql
                .= " WHERE node.pid='" . $params{'where'}{'value'} . "'";
        } elsif ( $params{'where'}{'type'} eq 'category' ) {
            require pf::nodecategory;
            my $cat      = $params{'where'}{'value'};
            my @catArray = pf::nodecategory::nodecategory_view($cat);
            if ( scalar(@catArray) == 1 ) {
                my $sqlWhere = $catArray[0]->{'sql'};
                $node_view_all_sql .= " WHERE " . $sqlWhere;
            }
        }
    }
    if ( defined( $params{'orderby'} ) ) {
        $node_view_all_sql .= " " . $params{'orderby'};
    }
    if ( defined( $params{'limit'} ) ) {
        $node_view_all_sql .= " " . $params{'limit'};
    }
    my $node_view_all_sth = $dbh->prepare($node_view_all_sql);
    return db_data($node_view_all_sth);
}

sub node_view_with_fingerprint {
    my ($mac) = @_;
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    $node_view_with_fingerprint_sql->execute($mac) || return (0);
    my $ref = $node_view_with_fingerprint_sql->fetchrow_hashref();

    # just get one row and finish
    $node_view_with_fingerprint_sql->finish();
    return ($ref);
}

sub node_modify {
    my ( $mac, %data ) = @_;
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
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
    my $old_status = $existing->{status};
    foreach my $item ( keys(%data) ) {
        $existing->{$item} = $data{$item};
        print "$item: $data{$item}\n";
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

    $node_modify_sql->execute(
        $new_mac,                      $existing->{pid},
        $existing->{detect_date},      $existing->{regdate},
        $existing->{unregdate},        $existing->{lastskip},
        $existing->{status},           $existing->{user_agent},
        $existing->{computername},     $existing->{notes},
        $existing->{dhcp_fingerprint}, $existing->{last_dhcp},
        $existing->{switch},           $existing->{port},
        $existing->{vlan},             $mac
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
            my %ConfigVlan;
            tie %ConfigVlan, 'Config::IniFiles',
                ( -file => "$conf_dir/switches.conf" );
            $info{'vlan'} = $ConfigVlan{'default'}{'normalVlan'};
            $logger->info( "auto-configured VLAN to " . $info{'vlan'} );
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

sub nodes_maintenance {
    my $logger = Log::Log4perl::get_logger('pf::node');
    node_db_prepare($dbh) if ( !$is_node_db_prepared );

    my $expire_mode = $Config{'registration'}{'expire_mode'};
    $logger->debug("nodes_maintenance called with expire_mode=$expire_mode");

    $node_ungrace_sql->execute() || return (0);
    my $rows = $node_ungrace_sql->rows;
    $logger->log( ( ( $rows > 0 ) ? $INFO : $DEBUG ),
        "modified $rows nodes from status 'grace' to 'unreg'" );

    if ( isdisabled($expire_mode) ) {
        return (1);
    } else {
        $node_expire_unreg_field_sql->execute() || return (0);
        $rows = $node_expire_unreg_field_sql->rows;
        $logger->log(
            ( ( $rows > 0 ) ? $INFO : $DEBUG ),
            "modified $rows nodes from status 'reg' to 'unreg' based on unregdate column"
        );
        if (  ( lc($expire_mode) eq 'window' )
            && $Config{'registration'}{'expire_window'} > 0 )
        {
            $node_expire_window_sql->execute() || return (0);
            $rows = $node_expire_window_sql->rows;
            $logger->log(
                ( ( $rows > 0 ) ? $INFO : $DEBUG ),
                "modified $rows nodes from status 'reg' to 'unreg' based on expiration window"
            );
        } elsif (  ( lc($expire_mode) eq 'deadline' )
            && ( time - $Config{'registration'}{'expire_deadline'} > 0 ) )
        {
            $node_expire_deadline_sql->execute() || return (0);
            $rows = $node_expire_deadline_sql->rows;
            $logger->log(
                ( ( $rows > 0 ) ? $INFO : $DEBUG ),
                "modified $rows nodes from status 'reg' to 'unreg' based on expiration deadline"
            );
        } elsif ( lc($expire_mode) eq 'session' ) {
            $node_expire_session_sql->execute() || return (0);
            $rows = $node_expire_session_sql->rows;
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

    node_db_prepare($dbh) if ( !$is_node_db_prepared );

    $node_unregistered_sql->execute($mac) || return (0);
    my $ref = $node_unregistered_sql->fetchrow_hashref();
    $node_unregistered_sql->finish();
    return ($ref);
}

sub nodes_unregistered {
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    return db_data($nodes_unregistered_sql);
}

sub nodes_registered {
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    return db_data($nodes_registered_sql);
}

sub nodes_registered_not_violators {
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    return db_data($nodes_registered_not_violators_sql);
}

sub nodes_active_unregistered {
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    return db_data($nodes_active_unregistered_sql);
}

sub node_expire_lastarp {
    my ($time) = @_;
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    return db_data( $node_expire_lastarp_sql, $time );
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
    node_db_prepare($dbh) if ( !$is_node_db_prepared );
    $node_update_lastarp_sql->execute($mac) || return (0);
    return (1);
}

#sub node_lookup_person {
#  my ($pid) = @_;
#  return(db_data($node_lookup_person_sql,$pid));
#}

#sub node_lookup_node {
#  my ($mac) = @_;
#  return(db_data($node_lookup_node_sql,$mac));
#}

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2007-2008 Inverse groupe conseil

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

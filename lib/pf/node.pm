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
use pf::log;
use Readonly;
use pf::StatsD::Timer;
use pf::util::statsd qw(called);
use pf::error qw(is_success is_error);
use pf::constants::parking qw($PARKING_VID);
use CHI::Memoize qw(memoized);
use pf::dal::node;
use pf::dal::locationlog;
use pf::constants::node qw(
    $STATUS_REGISTERED
    $STATUS_UNREGISTERED
    $STATUS_PENDING
    %ALLOW_STATUS
    $NODE_DISCOVERED_TRIGGER_DELAY
);
use pf::config qw(
    %Config
    $INLINE
    %connection_type_to_str
);

use constant NODE => 'node';

# Delay in millisecond to wait for triggering internal::node_discovered after discovering a node 
BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        node_exist
        node_pid
        node_delete
        node_add
        node_add_simple
        node_attributes
        node_attributes_with_fingerprint
        node_view
        node_count_all
        node_view_all
        node_view_reg_pid
        node_modify
        node_register
        node_deregister
        nodes_maintenance
        node_cleanup
        node_custom_search
        nodes_registered_not_violators
        is_node_voip
        is_node_registered
        is_max_reg_nodes_reached
        node_search
        $STATUS_REGISTERED
        node_last_reg
        node_defaults
        node_update_last_seen
        node_last_reg_non_inline_on_category
    );
}

use pf::constants;
use pf::config::violation;
use pf::config qw(
    %connection_type_to_str
    $INLINE
    $VOIP
    $NO_VOIP
);
use pf::db;
use pf::nodecategory;
use pf::constants::scan qw($SCAN_VID $POST_SCAN_VID);
use pf::util;
use pf::Connection::ProfileFactory;
use pf::ipset;
use pf::api::unifiedapiclient;

=head1 SUBROUTINES

TODO: This list is incomlete

=over

=cut

#
# return mac if the node exists
#
sub node_exist {
    my ($mac) = @_;
    $mac = clean_mac($mac);
    unless ($mac) {
        return (0);
    }
    my $status = pf::dal::node->exists({mac => $mac});
    return (is_success($status));
}

#
# return number of nodes for the specified pid and role id
#
sub node_pid {
    my ($pid, $category_id) = @_;
    my ($status, $count) = pf::dal::node->count(
        -where => {
            status => $STATUS_REGISTERED,
            pid => $pid,
            category_id => $category_id
        }
    );
    if (is_error($status)) {
        return (0);
    }
    return ($count);
}

#
# return mac for specified register pid
#
sub node_view_reg_pid {
    my ($pid) = @_;
    my ($status, $iter) = pf::dal::node->search(
        -where => {
            pid => $pid,
            status => $STATUS_REGISTERED
        },
        -columns => [qw(mac)]
    );
    my $items = $iter->all(undef);
    if ($items) {
        return @$items;
    }
    return;
}

#
# delete and return 1
#
sub node_delete {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ($mac, $tenant_id) = @_;
    my $logger = get_logger();

    $mac = clean_mac($mac);

    if ( !node_exist($mac) ) {
        $logger->error("delete of non-existent node '$mac' failed");
        return (0);
    }

    require pf::locationlog;
    # TODO that limitation is arbitrary at best, we need to resolve that.
    if ( defined( pf::locationlog::locationlog_view_open_mac($mac) ) ) {
        $logger->warn("$mac has an open locationlog entry. Node deletion prohibited");
        return (0);
    }
    my %options = (
        -where => {
            mac => $mac,
        }
    );
    if (defined $tenant_id) {
        $options{-where}{tenant_id} = $tenant_id;
        $options{-no_auto_tenant_id} = 1;
    }

    my ($status, $count) = pf::dal::node->remove_items(%options);
    if (is_error($status)) {
        return (0);
    }
    $logger->info("node $mac deleted");
    return (1);
}

our %DEFAULT_NODE_VALUES = (
    'autoreg'          => 'no',
    'bypass_vlan'      => '',
    'computername'     => '',
    'detect_date'      => $ZERO_DATE,
    'dhcp_fingerprint' => '',
    'last_arp'         => $ZERO_DATE,
    'last_dhcp'        => $ZERO_DATE,
    'lastskip'         => $ZERO_DATE,
    'notes'            => '',
    'pid'              => $default_pid,
    'regdate'          => $ZERO_DATE,
    'sessionid'        => '',
    'status'           => $STATUS_UNREGISTERED,
    'unregdate'        => $ZERO_DATE,
    'user_agent'       => '',
    'voip'             => 'no',
);

#
# clean input parameters and add to node table
#
sub node_add {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $mac, %data ) = @_;
    my $logger = get_logger();
    $logger->trace("node add called");

    $mac = clean_mac($mac);
    if ( !valid_mac($mac) ) {
        return (0);
    }
    $data{mac} = $mac;

    if ( node_exist($mac) ) {
        $logger->warn("attempt to add existing node $mac");
        return (2);
    }

    foreach my $field (keys %DEFAULT_NODE_VALUES)
    {
        $data{$field} = $DEFAULT_NODE_VALUES{$field} if ( !defined $data{$field} );
    }

    _cleanup_attributes(\%data);

    if ( ( $data{status} eq $STATUS_REGISTERED ) && ( $data{regdate} eq '' ) ) {
        $data{regdate} = mysql_date();
    }

    # category handling
    $data{'category_id'} = _node_category_handling(%data);
    if ( defined( $data{'category_id'} ) && $data{'category_id'} == 0 ) {
        $logger->error("Unable to insert node because specified category doesn't exist");
        return (0);
    }
    my $status = pf::dal::node->create(\%data);
    return (is_success($status) ? 1 : 0);
}

#
# simple wrapper for pfmon/pfdhcplistener-detected and auto-generated nodes
#
sub node_add_simple {
    my ($mac) = @_;
    my $date  = mysql_date();
    my %tmp   = (
        'pid'         => 'default',
        'detect_date' => $date,
        'status'      => 'unreg',
        'voip'        => 'no',
    );
    if ( !node_add( $mac, %tmp ) ) {
        return (0);
    } else {
        return (1);
    }
}

=item _cleanup_status_value

Cleans the status value to make sure that a valid status is being set

=cut

sub _cleanup_status_value {
    my ($status) = @_;
    unless ( defined $status && exists $ALLOW_STATUS{$status} ) {
        my $logger = get_logger();
        $logger->warn("The status was set to " . (defined $status ? $status : "'undef'") . " changing it $STATUS_UNREGISTERED" );
        $pf::StatsD::statsd->increment(called() . ".warn.count" );
        $status = $STATUS_UNREGISTERED;
    }
    return $status;
}

=item node_attributes

Returns information about a given MAC address (node)

It's a simpler and faster version of node_view with fewer fields returned.

=cut

sub node_attributes {
    my ($mac) = @_;
    $mac = clean_mac($mac);
    my ($status, $obj) = pf::dal::node->find({mac => $mac});
    if (is_error($status)) {
        return (undef);
    }
    return ($obj->to_hash);
}

=item node_attributes_with_fingerprint

Returns information about a given MAC address (node) with the DHCP
fingerprint class as a string.

It's a simpler and faster version of node_view_with_fingerprint with
fewer fields returned.

=cut

sub node_attributes_with_fingerprint {
    my ($mac) = @_;
    return node_attributes($mac);
}

=item _node_view

The real implementation of node_view

=cut

sub _node_view {
    my ($mac) = @_;
    pf::log::logstacktrace("pf::node::node_view getting '$mac'");
    my ($status, $obj) = pf::dal::node->find({mac => $mac});
    if (is_error($status)) {
        return (undef);
    }
    $obj->_load_locationlog;
    return ($obj->to_hash());
}

=item node_view

Returning lots of information about a given MAC address (node).

New implementation in 3.2.0.

=cut

sub node_view {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ($mac) = @_;
    $mac = clean_mac($mac);
    if ($mac) {
        return _node_view($mac);
    }
    return undef;
}

sub node_count_all {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $id, %params ) = @_;
    my $logger = get_logger();

    my @conditions;
    my @where = ();
    if ( defined( $params{'where'} ) ) {
        my $where = $params{'where'};
        if ( $where->{'type'} ) {
            if ( $where->{'type'} eq 'pid' ) {
                push @conditions, {pid => $where->{'value'}};
            }
            elsif ( $where->{'type'} eq 'category' ) {
                my $cat_id = nodecategory_lookup($where->{'value'});
                if (!defined($cat_id)) {
                    # lets be nice and issue a warning if the category doesn't exist
                    $logger->warn("there was a problem looking up category " . $where->{'value'});
                    # put cat_id to 0 so it'll return 0 results (achieving the count ok)
                    $cat_id = 0;
                }
                push @conditions, {category_id => $cat_id};
            }
            elsif ( $where->{'type'} eq 'status') {
                push @conditions, {status => $where->{'value'}};
            }
            elsif ( $where->{'type'} eq 'any' ) {
                if (exists($where->{'like'})) {
                    my $like = '%' . $where->{'like'} . '%';
                    my $like_op = {'-like' => $like};
                    push @conditions, [ -or => [{mac => $like_op}, { computername => $like_op  }, { pid => $like_op}]];
                }
            }
        }
        if ( ref($where->{'between'}) ) {
            my $between = $where->{'between'};
            push(@conditions, {$between->[0] => {-between => [@{$between}[1, 2]]}});
        }
        if (@conditions) {
            @where = (-and => \@conditions);
        }
    }
    my ($status, $count) = pf::dal::node->count(
        -where => \@where
    );
    return {nb => $count};
}

sub node_custom_search {
    my ($sql) = @_;
    my ($status, $sth) = pf::dal::node->db_execute($sql);
    if (is_error($status)) {
        return;
    }
    return @{$sth->fetchall_arrayref({}) // []};
}

=item * node_view_all - view all nodes based on several criteria

Warning: The connection_type field is translated into its human form before return.

=cut

sub node_view_all {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $id, %params ) = @_;
    my $logger = get_logger();
#      SELECT node.mac, node.pid, node.voip, node.bypass_vlan, node.status,
#           IF(ISNULL(nc.name), '', nc.name) as category,
#           IF(ISNULL(nr.name), '', nr.name) as bypass_role ,
#           IF(node.detect_date = $ZERO_DATE, '', node.detect_date) as detect_date,
#           IF(node.regdate = $ZERO_DATE, '', node.regdate) as regdate,
#           IF(node.unregdate = $ZERO_DATE, '', node.unregdate) as unregdate,
#           IF(node.lastskip = $ZERO_DATE, '', node.lastskip) as lastskip,
#           node.user_agent, node.computername, device_class AS dhcp_fingerprint,
#           node.last_arp, node.last_dhcp, node.last_seen,
#           locationlog.switch as last_switch, locationlog.port as last_port, locationlog.vlan as last_vlan,
#           IF(ISNULL(locationlog.connection_type), '', locationlog.connection_type) as last_connection_type,
#           locationlog.dot1x_username as last_dot1x_username, locationlog.ssid as last_ssid,
#           locationlog.stripped_user_name as stripped_user_name, locationlog.realm as realm,
#           locationlog.switch_mac as last_switch_mac,
#           ip4log.ip as last_ip,
#           COUNT(DISTINCT violation.id) as nbopenviolations,
#           node.notes
#       FROM node
#           LEFT JOIN node_category as nr on node.bypass_role_id = nr.category_id
#           LEFT JOIN node_category as nc on node.category_id = nc.category_id
#           LEFT JOIN violation ON node.mac=violation.mac AND violation.status = 'open'
#           LEFT JOIN locationlog ON node.mac=locationlog.mac AND  = 0
#           LEFT JOIN ip4log ON node.mac=ip4log.mac AND (ip4log. = $ZERO_DATE OR ip4log.end_time > NOW())
#       GROUP BY node.mac
    my $columns = [
        qw(node.mac node.pid node.voip node.bypass_vlan node.status),
        \"IF(ISNULL(nc.name), '', nc.name) as category",
        \"IF(ISNULL(nr.name), '', nr.name) as bypass_role",
        \"IF(node.detect_date = '$ZERO_DATE', '', node.detect_date) as detect_date",
        \"IF(node.regdate = '$ZERO_DATE', '', node.regdate) as regdate",
        \"IF(node.unregdate = '$ZERO_DATE', '', node.unregdate) as unregdate",
        \"IF(node.lastskip = '$ZERO_DATE', '', node.lastskip) as lastskip",
        qw(
          node.user_agent node.computername device_class|dhcp_fingerprint
          node.last_arp node.last_dhcp node.last_seen
          locationlog.switch|last_switch locationlog.port|last_port locationlog.vlan|last_vlan),
        \"IF(ISNULL(locationlog.connection_type), '', locationlog.connection_type) as last_connection_type",
        qw(
          locationlog.dot1x_username|last_dot1x_username locationlog.ssid|last_ssid
          locationlog.stripped_user_name|stripped_user_name locationlog.realm|realm
          locationlog.switch_mac|last_switch_mac
          ip4log.ip|last_ip
          ),
        \"COUNT(DISTINCT violation.id) as nbopenviolations",
        'node.notes'
    ];

    my $from = [-join => qw(
        node 
        =>{nr.category_id=node.bypass_role_id} node_category|nr
        =>{node.category_id=nc.category_id} node_category|nc
        ),
        {
            operator  => '=>',
            condition => {
                'node.mac' => { '=' => { -ident => '%2$s.mac' } },
                '%2$s.status' => 'open',
            },
        },
        'violation',
        {
            operator  => '=>',
            condition => {
                'node.mac' => { '=' => { -ident => '%2$s.mac' } },
                '%2$s.' => $ZERO_DATE,
            },
        },
        'locationlog',
        {
            operator  => '=>',
            condition => {
                'node.mac' => { '=' => { -ident => '%2$s.mac' } },
                '%2$s.' => [$ZERO_DATE, { ">", \'NOW()'}],
            },
        },
        'ip4log'
    ];

    my $extra = {
        -from => $from,
        -columns => $columns,
        -group_by => 'node.mac',
    };

    if ( defined( $params{'where'} ) ) {
        if ( $params{'where'}{'type'} eq 'pid' ) {
            $extra->{-having} = {
                'node.pid' => $params{'where'}{'value'}
            };
        }
        elsif ( $params{'where'}{'type'} eq 'category' ) {

            if (!nodecategory_lookup($params{'where'}{'value'})) {
                # lets be nice and issue a warning if the category doesn't exist
                $logger->warn("there was a problem looking up category ".$params{'where'}{'value'});
            }
            $extra->{-having} = {
                'category' => $params{'where'}{'value'}
            };
        }
        elsif ( $params{'where'}{'type'} eq 'any' ) {
            my $like = $params{'where'}{'like'};
            $like =~ s/^ *//;
            $like =~ s/ *$//;
            if (valid_mac($like) && !valid_ip($like)) {
                my $mac = clean_mac($like);
                $extra->{-having} = {
                    'node.pid' => $params{'where'}{'value'}
                };
            }
            else {
                $like = '%' . $params{'where'}{'like'} . '%';
                $extra->{-having} = [ map { { $_ => { -like => $like} } } qw(node.mac node.computername node.pid ip4log.ip)  ];
            }
        }
    }
    if ( defined( $params{'orderby'} ) ) {
        $extra->{-order_by} = $params{'orderby'},
    }
    if ( defined( $params{'limit'} ) ) {
        $extra->{-limit} = $params{'limit'};
        $extra->{-offset} = $params{'offset'};
    }


    require pf::pfcmd::report;
    import pf::pfcmd::report;
    my ($status, $iter) = pf::dal::node->search(%$extra);
    if (is_error($status)) {
        return;
    }
    print $iter->rows,"\n";
    my @data = translate_connection_type(@{$iter->all(undef) // []});
    return @data;
}

sub node_modify {
    my $timer = pf::StatsD::Timer->new;
    my ( $mac, %data ) = @_;
    my $logger = get_logger();

    # validation
    $mac = clean_mac($mac);
    if ( !valid_mac($mac) ) {
        $logger->error("Invalid mac ($mac)");
        return (0);
    }
    # Find or create the node
    my ($status, $obj) = pf::dal::node->find_or_create({
        %data,
        mac => $mac
    });

    if (is_error($status)) {
        return (0);
    }

    if ($status == $STATUS::CREATED) {
        return 1;
    }
    # Fail if renaming mac
    #
    if (exists $data{mac} && defined $data{mac}) {
        my $new_mac = clean_mac($data{mac});
        if (defined $new_mac && $new_mac ne $mac) {
            return (0);
        }
    }

    my $node_info = node_view($mac);
    if (defined($data{'category_id'}) && defined($obj->{'category_id'}) && ($obj->{'category_id'} ne $data{'category_id'}) && ($obj->{'status'} eq $STATUS_REGISTERED) && defined($node_info->{'last_connection_type'}) && $node_info->{'last_connection_type'} eq $connection_type_to_str{$INLINE}) {
        pf::ipset::iptables_update_set($mac, $obj->{'category_id'}, $data{'category_id'});
    }

    $obj->merge(\%data);
    $status = $obj->save();
    if (is_error($status)) {
        $logger->error("Unable to modify node '" . $mac // 'undef' . "'");
        return (0);
    }
    return (1);
}

sub node_register {
    my $timer = pf::StatsD::Timer->new();
    my ( $mac, $pid, %info ) = @_;
    my $logger = get_logger();
    $mac = lc($mac);
    my $auto_registered = 0;

    my $status_msg = "";

    # hack to support an additional autoreg param to the sub without changing the hash to a reference everywhere
    if (defined($info{'auto_registered'})) {
        $auto_registered = 1;
    }

    require pf::person;
    require pf::lookup::person;
    # create a person entry for pid if it doesn't exist
    if ( !pf::person::person_exist($pid) ) {
        $logger->info("creating person $pid because it doesn't exist");
        pf::person::person_add($pid);
        pf::lookup::person::async_lookup_person($pid,$info{'source'});

    } else {
        $logger->debug("person $pid already exists");
    }
    pf::person::person_modify($pid,
                    'source'  => $info{'source'},
                    'portal'  => $info{'portal'},
    );
    delete $info{'source'};
    delete $info{'portal'};

    # if it's for auto-registration and mac is already registered, we are done
    if ($auto_registered) {
       my $node_info = node_view($mac);
       if (defined($node_info) && (ref($node_info) eq 'HASH') && $node_info->{'status'} eq 'reg') {
        $info{'pid'} = $pid;
        if ( !node_modify( $mac, %info ) ) {
            $logger->error("modify of node $mac failed");
            return (0);
        }
           $logger->info("autoregister a node that is already registered, do nothing.");
           return (1);
       }
    }
    else {
    # do not check for max_node if it's for auto-register
        if ( is_max_reg_nodes_reached($mac, $pid, $info{'category'}, $info{'category_id'}) ) {
            $status_msg = "max nodes per pid met or exceeded";
            $logger->error( "$status_msg - registration of $mac to $pid failed" );
            return ($FALSE, $status_msg);
        }
    }

    $info{'pid'}     = $pid;
    $info{'status'}  = 'reg';
    $info{'regdate'} = mysql_date();

    if ( !node_modify( $mac, %info ) ) {
        $logger->error("modify of node $mac failed");
        return (0);
    }
    $pf::StatsD::statsd->increment( called() . ".called" );

    # Closing any parking violations
    # loading pf::violation here to prevent circular dependency
    require pf::violation;
    pf::violation::violation_force_close($mac, $PARKING_VID);

    my $profile = pf::Connection::ProfileFactory->instantiate($mac);
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

    return (1);
}

sub node_deregister {
    my $timer = pf::StatsD::Timer->new;
    my ($mac, %info) = @_;
    my $logger = get_logger();
    $pf::StatsD::statsd->increment( called() . ".called" );

    $info{'status'}    = 'unreg';
    $info{'regdate'}   = $ZERO_DATE;
    $info{'unregdate'} = $ZERO_DATE;
    $info{'lastskip'}  = $ZERO_DATE;
    $info{'autoreg'}   = 'no';

    my $profile = pf::Connection::ProfileFactory->instantiate($mac);
    if(my $provisioner = $profile->findProvisioner($mac)){
        if(my $pki_provider = $provisioner->getPkiProvider() ){
            if(isenabled($pki_provider->revoke_on_unregistration)){
                my $node_info = node_view($mac);
                my $cn = $pki_provider->user_cn($node_info);
                $pki_provider->revoke($cn);
            }
        }
    }

    if ( !node_modify( $mac, %info ) ) {
        $logger->error("unable to de-register node $mac");
        return (0);
    }

    eval {
        pf::api::unifiedapiclient->default_client->call("DELETE", "/api/v1/dhcp/mac/".$mac,{});
    };

    if ($@) {
        $logger->error("Error releasing ip for $mac : $@");
    }

    return (1);
}

=item * nodes_maintenance - handling deregistration on node expiration and node grace

called by pfmon daemon for the configured interval

=cut

sub nodes_maintenance {
    my $timer = pf::StatsD::Timer->new;
    my $logger = get_logger();
    local $pf::dal::CURRENT_TENANT = $pf::dal::CURRENT_TENANT;

    $logger->debug("nodes_maintenance called");
    my ( $status, $iter ) = pf::dal::node->search(
        -where => {
            status    => { "!=" => "unreg" },
            unregdate => [-and => { "!=" => $ZERO_DATE }, { "<"  => \['NOW()'] } ]
        },
        -columns => ['mac', 'tenant_id'],
        -no_auto_tenant_id => 1,
        -with_class => undef,
    );
    if (is_error($status)) {
        return (0);
    }

    while (my $row = $iter->next()) {
        my $currentMac = $row->{mac};
        pf::dal->set_tenant($row->{tenant_id});
        node_deregister($currentMac);
        require pf::enforcement;
        pf::enforcement::reevaluate_access( $currentMac, 'manage_deregister' );

        $logger->info("modified $currentMac from status 'reg' to 'unreg' based on unregdate colum" );
    }

    return (1);
}

=item nodes_registered_not_violators

Returns a list of MACs which are registered and don't have any open violation.
Since trap violations stay open, this has the intended effect of getting all MACs which should be allowed through.

=cut

sub nodes_registered_not_violators {
    my ($status, $iter) = pf::dal::node->search(
        -where => {
            'node.status' => "reg"
        },
        -columns  => [qw(node.mac node.category_id)],
        -group_by => 'node.mac',
        -having => 'count(violation.mac)=0',
        -from => [-join => 'node', "=>{node.mac=violation.mac,violation.status='open'}", "violation"],
    );
    if (is_error($status)) {
        return;
    }
    return @{ $iter->all(undef) // []};
}

=item node_expire_lastseen

Get the nodes that should be deleted based on the last_seen column 

=cut

sub node_expire_lastseen {
    my ($time) = @_;
    my ( $status, $iter ) = pf::dal::node->search(
        -where => {
            status    => "unreg",
            last_seen => { "!=" => $ZERO_DATE },
            -and => [
                \['unix_timestamp(last_seen) < (unix_timestamp(now()) - ?)', $time],
            ]
        },
        -columns => ['mac', 'tenant_id'],
        -no_auto_tenant_id => 1,
    );
    if (is_error($status)) {
        return;
    }
    return @{ $iter->all(undef) // []};
}

=item node_unreg_lastseen

Get the nodes that should be unregistered based on the last_seen column 

=cut

sub node_unreg_lastseen {
    my ($time) = @_;
    my ( $status, $iter ) = pf::dal::node->search(
        -where => {
            status    => { "!=" => "unreg"},
            last_seen => { "!=" => $ZERO_DATE },
            -and => [
                \['unix_timestamp(last_seen) < (unix_timestamp(now()) - ?)', $time],
            ]
        },
        -columns => ['mac', 'tenant_id'],
        -no_auto_tenant_id => 1,
    );
    if (is_error($status)) {
        return;
    }
    return @{ $iter->all(undef) // []};
}

=item node_cleanup

Cleanup nodes that should be deleted or unregistered based on the maintenance parameters

=cut

sub node_cleanup {
    my $timer = pf::StatsD::Timer->new;
    my ($delete_time, $unreg_time) = @_;
    my $logger = get_logger();
    $logger->debug("calling node_cleanup with delete_time=$delete_time unreg_time=$unreg_time");
    
    if($delete_time ne "0") {
        foreach my $row ( node_expire_lastseen($delete_time) ) {
            my $mac = $row->{'mac'};
            my $tenant_id = $row->{'tenant_id'};
            $logger->info("mac $mac not seen for $delete_time seconds, deleting");

            require pf::locationlog;
            pf::locationlog::locationlog_update_end_mac($mac, $tenant_id);
            node_delete($mac, $tenant_id);
        }
    }
    else {
        $logger->debug("Not deleting because the window is 0");
    }

    if($unreg_time ne "0") {
        local $pf::dal::CURRENT_TENANT = $pf::dal::CURRENT_TENANT;
        foreach my $row ( node_unreg_lastseen($unreg_time) ) {
            my $mac = $row->{'mac'};
            my $tenant_id = $row->{'tenant_id'};
            $logger->info("mac $mac not seen for $unreg_time seconds, unregistering");
            pf::dal->set_tenant($tenant_id);
            node_deregister($mac);
            # not reevaluating access since the node is be inactive
        }
    }
    else {
        $logger->debug("Not unregistering because the window is 0");
    }

    return (0);
}

=item * node_update_bandwidth - update the bandwidth balance of a node

Updates the bandwidth balance of a node and close the violations that use the bandwidth trigger.

=cut

sub node_update_bandwidth {
    my $timer = pf::StatsD::Timer->new;
    my ($mac, $bytes) = @_;
    my $logger = get_logger();

    # Validate arguments
    $mac = clean_mac($mac);
    $logger->logdie("Invalid MAC address") unless (valid_mac($mac));
    $logger->logdie("Invalid number of bytes") unless ($bytes =~ m/^\d+$/);
    my ($status, $rows) = pf::dal::node->update_items(
        -set => {
            bandwidth_balance => \['COALESCE(bandwidth_balance, 0) + ?', $bytes],
        }, 
        -where => {
            mac => $mac
        }
    );

    if (is_error($status)) {
        return (undef);
    }
    if ($rows) {
        foreach my $vid (@BANDWIDTH_EXPIRED_VIOLATIONS){
            pf::violation::violation_force_close($mac, $vid);
        }
    }
    return ($rows);
}

sub node_search {
    my ($mac) = @_;
    my ($status, $iter) = pf::dal::node->search(
        -where => {
            mac => {-like => "${mac}%"}
        }, 
        -columns => ['mac']
    );
    if (is_error($status)) {
        return;
    }
    my $items = $iter->sth->fetchall_arrayref;
    $iter->finish();
    return map { $_->[0] } @$items;
}

=item * is_node_voip

Is given MAC a VoIP Device or not?

in: mac address

=cut

sub is_node_voip {
    my ($mac) = @_;
    my ($status, $iter) = pf::dal::node->search(
        -where => {
            mac => $mac,
            voip => $VOIP
        },
        -columns => [\1]
    );
    if (is_error($status)) {
        return $FALSE;
    }
    my $items = $iter->all(undef);
    if (!defined $items) {
        return $FALSE;
    }
    return scalar @$items ? $TRUE : $FALSE; 
}

=item * is_node_registered

Is given MAC registered or not?

in: mac address

=cut

sub is_node_registered {
    my ($mac) = @_;
    my $logger = get_logger();
    $logger->trace("Asked whether node $mac is registered or not");
    my ($status, $iter) = pf::dal::node->search(
        -where => {
            mac    => $mac,
            status => $STATUS_REGISTERED,
        },
        -columns => [\1],
    );
    if (is_error($status)) {
        return $FALSE;
    }
    my $items = $iter->all(undef);
    if (!defined $items) {
        return $FALSE;
    }
    return scalar @$items ? $TRUE : $FALSE; 
}

=item * node_category_handling - assigns category_id based on provided data

expects category_id or category name in the form of category => 'name' or category_id => id

returns category_id, undef if no category was required or 0 if no category is found (which is a problem)

=cut

sub _node_category_handling {
    my $timer = pf::StatsD::Timer->new({level => 7});
    my (%data) = @_;
    my $logger = get_logger();

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

=item is_max_reg_nodes_reached

Performs the enforcement of the maximum number of registered nodes allowed per user for a specific role.

The MAC address is currently not used.

=cut

sub is_max_reg_nodes_reached {
    my $timer = pf::StatsD::Timer->new({ level => 6 });
    my ($mac, $pid, $category, $category_id) = @_;
    my $logger = get_logger();

    # default_pid is a special case: no limit for this user
    if ($pid eq $default_pid || $pid eq $admin_pid) {
        return $FALSE;
    }
    # per-category max node per pid limit
    if ( $category || $category_id ) {
        my $category_info;
        my $nb_nodes;
        my $max_for_category;
        if ($category) {
            $category_info = nodecategory_view_by_name($category);
        } else {
            $category_info = nodecategory_view($category_id);
        }

        if ( defined($category_info->{'max_nodes_per_pid'}) ) {
            $nb_nodes = node_pid($pid, $category_info->{'category_id'});
            $max_for_category = $category_info->{'max_nodes_per_pid'};
            if ( $max_for_category == 0 || $nb_nodes < $max_for_category ) {
                return $FALSE;
            }
            $logger->info("per-role max nodes per-user limit reached: $nb_nodes are already registered to pid $pid for role "
                          . $category_info->{'name'});
        }
        else {
            $logger->warn("Specified role ".($category?$category:$category_id)." doesn't exist for pid $pid (MAC $mac); assume maximum number of registered nodes is reached");
        }
    }
    else {
        $logger->warn("No role specified or found for pid $pid (MAC $mac); assume maximum number of registered nodes is reached");
    }

    # fallback to maximum reached
    return $TRUE;
}

=item _cleanup_attributes

Cleans up any inconsistency in the info attributes

=cut

sub _cleanup_attributes {
    my ($info) = @_;
    my $voip = $info->{voip};
    $info->{voip} = $NO_VOIP if !defined ($voip) || $voip ne $VOIP;
    $info->{'status'} = _cleanup_status_value($info->{'status'});
}

=item fingerbank_info

Get a hash containing the fingerbank related informations for a node

=cut

sub fingerbank_info {
    my ($mac, $node_info) = @_;
    $node_info ||= pf::node::node_view($mac);

    my $info = {};

    my $cache = pf::fingerbank::cache();

    unless(defined($node_info->{device_type})){
        my $info = {};
        $info->{device_hierarchy_names} = [];
        $info->{device_hierarchy_ids} = [];
        return $info;
    }

    $info->{device_name} = $node_info->{device_type};

    my $device_info = {};
    my $cache_key = 'fingerbank_info::DeviceHierarchy-'.$node_info->{device_type};
    eval {
        $device_info = $cache->compute_with_undef($cache_key, sub {
            my $info = {};

            my $device_id = pf::fingerbank::device_name_to_device_id($node_info->{device_type});
            if(defined($device_id)) {
                my $device = fingerbank::Model::Device->read($device_id, $TRUE);
                $info->{device_hierarchy_names} = [$device->name, map {$_->name} @{$device->{parents}}];
                $info->{device_hierarchy_ids} = [$device->id, map {$_->id} @{$device->{parents}}];
                $info->{device_fq} = join('/',reverse(@{$info->{device_hierarchy_names}}));
                $info->{mobile} = $device->mobile;
            }
            else {
                get_logger->warn("Impossible to find device information for $node_info->{device_type}");
                $info->{device_hierarchy_names} = [];
                $info->{device_hierarchy_ids} = [];
            }
            return $info;
        });
        $info->{score} = $node_info->{device_score};
        $info->{version} = $node_info->{device_version};

        $info ={ (%$info, %$device_info) };
    };
    if($@) {
        get_logger->error("Unable to compute Fingerbank device information for $mac. Device profiling rules relying on it will not work. ($@)");
        $cache->remove($cache_key);
    }

    return $info;
}

=item node_defaults

create the node defaults

=cut

sub node_defaults {
    my ($mac) = @_;
    my $node_info = pf::dal::node->_defaults;
    $node_info->{mac} = $mac;
    return $node_info;
}

=item node_update_last_seen 

Update the last_seen attribute of a node to now

=cut

sub node_update_last_seen {
    my ($mac) = @_;
    $mac = clean_mac($mac);
    if ($mac) {
        my ($status, $rows) = pf::dal::node->update_items(
            -set => {
                last_seen => \['NOW()']
            }, 
            -where => {
                mac => $mac
            }
        );
    }
}


=item check_multihost

Verify, based on open location log for a MAC, if there's more than one endpoint on a switchport.

location_info is an optionnal hashref containing switch ID, switch port and connection type. If provided, there is no need to look them up.

=cut

sub check_multihost {
    my ( $mac, $location_info ) = @_;
    my $logger = get_logger();

    return unless isenabled($Config{'advanced'}{'multihost'});

    $mac = clean_mac($mac);
    unless ( defined $location_info && ($location_info->{'switch_id'} ne "") && ($location_info->{'switch_port'} ne "") && ($location_info->{'connection_type'} ne "") ) {
        my ($status, $iter) = pf::dal::locationlog->search(
            -where => {
                mac => $mac,
                end_time => $ZERO_DATE,
            },
            -limit => 1,
        );
        if (is_success($status)) {
            my $locationlog_info_ref = $iter->next(undef);
            if ($locationlog_info_ref) {
                $location_info->{'switch_id'} = $locationlog_info_ref->{'switch'};
                $location_info->{'switch_port'} = $locationlog_info_ref->{'port'};
                $location_info->{'connection_type'} = $locationlog_info_ref->{'connection_type'} // '';
            }
        }
    }

    # There is no "multihost" capabilities for wireless or inline connections
    if ( ($location_info->{'connection_type'} =~ /^Wireless/)  || ($location_info->{'connection_type'} =~ /^Inline/) ) {
        $logger->debug("Not looking up multihost presence with MAC '$mac' since it is a '$location_info->{'connection_type'}' connection");
        return;
    }

    $logger->debug("Looking up multihost presence on switch ID '$location_info->{'switch_id'}', switch port '$location_info->{'switch_port'}' (with MAC '$mac')");

    my @locationlog = pf::locationlog::locationlog_view_open_switchport_no_VoIP($location_info->{'switch_id'}, $location_info->{'switch_port'});

    return unless scalar @locationlog > 1;

    my @mac;
    $logger->info("Found '" . scalar @locationlog . "' active devices on switch ID '$location_info->{'switch_id'}', switch port '$location_info->{'switch_port'}' (with MAC '$mac')");
    for my $entry ( @locationlog ) {
        push @mac, $entry->{'mac'};
    }

    return @mac;
}


=item node_last_reg_non_inline_on_category

Return the last mac that has been registered in a specific category
May be sometimes usefull for custom

=cut

sub node_last_reg_non_inline_on_category {
    my ( $mac,    $category ) = @_;
    my ( $status, $iter )     = pf::dal::node->search(
        -where => {
            'node.mac'             => { '!=', $mac },
            'node_category.name'   => $category,
            'locationlog.end_time' => $ZERO_DATE,
            'locationlog.connection_type' => { "!=" => $connection_type_to_str{$INLINE} },
        },
        -columns => [qw(node.mac)],
        -from    => [
            -join => 'node',
            "<={node.mac=locationlog.mac}",
            "locationlog",
            '<={node.category_id=node_category.category_id}',
            'node_category',
        ],
        -limit      => 1,
        -order_by   => { -desc => 'node.regdate' },
        -with_class => undef,
    );
    if ( is_error($status) ) {
        return;
    }
    my $all = $iter->all();
    my $result = $all ? $all->[0] : undef;
    return $result;
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

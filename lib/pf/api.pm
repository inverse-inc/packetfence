package pf::api;

=head1 NAME

pf::api RPC methods exposing PacketFence features

=cut

=head1 DESCRIPTION

pf::api

=cut

use strict;
use warnings;

use JSON::MaybeXS;
use base qw(pf::api::attributes);
use threads::shared;
use pf::log();
use pf::authentication();
use pf::Authentication::constants;
use pf::config();
use pf::config::util();
use pf::config::trapping_range;
use pf::ConfigStore::Interface();
use pf::ConfigStore::Pf();
use pf::ConfigStore::Roles();
use pf::ConfigStore::TrafficShaping();
use pf::ip4log();
use pf::fingerbank;
use pf::Connection::ProfileFactory();
use pf::radius::custom();
use pf::violation();
use pf::util();
use pf::node();
use pf::locationlog();
use pf::ipset();
use pfconfig::util;
use pfconfig::manager;
use pf::api::jsonrpcclient;
use pf::cluster;
use fingerbank::DB;
use File::Slurp;
use pf::file_paths qw($captiveportal_profile_templates_path);
use pf::CHI;
use pf::metadefender();
use pf::services();
use pf::firewallsso();
use pf::pfqueue::stats();
use pf::pfqueue::producer::redis();

use List::MoreUtils qw(uniq);
use List::Util qw(pairmap);
use File::Copy::Recursive qw(dircopy);
use NetAddr::IP;

use pf::radius::rest();
use pf::radius::constants;
use pf::scan();
use pf::person();
use pf::lookup::person();
use pf::enforcement();
use pf::password();
use pf::web::guest();
use pf::dhcp::processor_v4();
use pf::dhcp::processor_v6();
use pf::util::dhcpv6();
use pf::domain::ntlm_cache();
use Hash::Merge qw (merge);

use pf::constants::api;
use pf::constants::realm;
use DateTime::Format::MySQL;

sub event_add : Public {
    my ($class, %postdata) = @_;
    my $logger = pf::log::get_logger();
    my $events = $postdata{'events'};
    my $srcip = pf::util::clean_ip($postdata{'srcip'});
    my $dstip = pf::util::clean_ip($postdata{'dstip'});
    if ( !defined $events || keys %$events == 0) {
        $logger->warn("No events to add for " . (defined $srcip ? "source ip $srcip": "unknown source ip" ) . (defined $dstip ? "destination ip $dstip " : "unknown destination ip") );
        return;
    }
    if ((!defined($srcip) ) && (!defined($dstip))) {
        $logger->warn("Received event(s) with out a source or destination id");
        return;
    }
    my $srcmac = pf::ip4log::ip2mac($srcip) if defined $srcip;
    # If trapping range is defined then check
    my $range = $pf::config::Config{'fencing'}{'range'};
    if (defined ($range) && $range ne '') {
        my $dstmac = pf::ip4log::ip2mac($dstip) if defined $dstip;
        my ($source_net_ip, $dest_net_ip);
        $source_net_ip = NetAddr::IP::Lite->new($srcip) if defined $srcmac;
        $dest_net_ip = NetAddr::IP::Lite->new($dstip) if defined $dstmac;
        foreach my $net_addr (@TRAPPING_RANGE) {
            if (defined $srcmac) {
                if ($net_addr->contains($source_net_ip)) {
                    while( my ($type, $id) = each %$events) {
                        pf::violation::violation_trigger( { 'mac' => $srcmac, 'tid' => $id, 'type' => $type } );
                    }
                }
            }
            if (defined $dstmac) {
                if ($net_addr->contains($dest_net_ip)) {
                    while( my ($type, $id) = each %$events) {
                        pf::violation::violation_trigger( { 'mac' => $dstmac, 'tid' => $id, 'type' => $type } );
                    }
                }
            }
        }
    }
    else {
        if (defined $srcmac) {
            while( my ($type, $id) = each %$events) {
                pf::violation::violation_trigger( { 'mac' => $srcmac, 'tid' => $id, 'type' => $type } );
            }
        }
    }

}

sub echo : Public {
    my ($class, @args) = @_;
    return @args;
}

sub radius_authorize : Public {
    my ($class, %radius_request) = @_;
    my $logger = pf::log::get_logger();

    my $radius = new pf::radius::custom();
    my $return;
    eval {
        $return = $radius->authorize(\%radius_request);
    };
    if ($@) {
        $logger->error("radius authorize failed with error: $@");
    }

    return $return;
}

sub radius_accounting : Public {
    my ($class, %radius_request) = @_;
    my $logger = pf::log::get_logger();

    my $radius = new pf::radius::custom();
    my $return;
    eval {
        $return = $radius->accounting(\%radius_request);
    };
    if ($@) {
        $logger->error("radius accounting failed with error: $@");
    }
    return $return;
}

sub radius_update_locationlog : Public {
    my ($class, %radius_request) = @_;
    my $logger = pf::log::get_logger();

    my $radius = new pf::radius::custom();
    my $return;
    eval {
        $return = $radius->update_locationlog_accounting(\%radius_request);
    };
    if ($@) {
        $logger->error("radius update locationlog accounting failed with error: $@");
    }
    return $return;
}

=head2 radius_switch_access

Return RADIUS attributes to allow switch's CLI access

=cut

sub radius_switch_access : Public {
    my ($class, %radius_request) = @_;
    my $logger = pf::log::get_logger();

    my $radius = new pf::radius::custom();
    my $return;
    eval {
        $return = $radius->switch_access(\%radius_request);
    };
    if ($@) {
        $logger->error("radius switch access failed with error: $@");
    }
    return $return;
}


=head2 update_ip4log

Update ip4log based on provided IP addresses and MAC addresses

=cut

sub update_ip4log : Public :AllowedAsAction(mac, $mac, ip, $ip) {
    my ($class, %postdata) = @_;
    my @require = qw(mac ip);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    $postdata{'oldip'}  = pf::ip4log::mac2ip($postdata{'mac'}) if (!defined($postdata{'oldip'}));
    $postdata{'oldmac'} = pf::ip4log::ip2mac($postdata{'ip'}) if (!defined($postdata{'oldmac'}));

    if ( $postdata{'oldmac'} && $postdata{'oldmac'} ne $postdata{'mac'} ) {
        $logger->info(
            "oldmac ($postdata{'oldmac'}) and newmac ($postdata{'mac'}) are different for $postdata{'ip'} - closing ip4log entry"
        );
        pf::ip4log::close($postdata{'ip'});
    } elsif ($postdata{'oldip'} && $postdata{'oldip'} ne $postdata{'ip'}) {
        $logger->info(
            "oldip ($postdata{'oldip'}) and newip ($postdata{'ip'}) are different for $postdata{'mac'} - closing ip4log entry"
        );
        pf::ip4log::close($postdata{'oldip'});
    }

    return (pf::ip4log::open($postdata{'ip'}, $postdata{'mac'}, $postdata{'lease_length'}));
}


=head2 update_ip6log

Update ip6log based on provided IP addresses and MAC addresses

=cut

sub update_ip6log : Public :AllowedAsAction(mac, $mac, ip, $ip) {
    my ($class, %postdata) = @_;
    my @require = qw(mac ip);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    $postdata{'oldip'}  = pf::ip6log::mac2ip($postdata{'mac'}) if (!defined($postdata{'oldip'}));
    $postdata{'oldmac'} = pf::ip6log::ip2mac($postdata{'ip'}) if (!defined($postdata{'oldmac'}));

    if ( $postdata{'oldmac'} && $postdata{'oldmac'} ne $postdata{'mac'} ) {
        $logger->info(
            "oldmac ($postdata{'oldmac'}) and newmac ($postdata{'mac'}) are different for $postdata{'ip'} - closing ip6log entry"
        );
        pf::ip6log::close($postdata{'ip'});
    } elsif ($postdata{'oldip'} && $postdata{'oldip'} ne $postdata{'ip'}) {
        $logger->info(
            "oldip ($postdata{'oldip'}) and newip ($postdata{'ip'}) are different for $postdata{'mac'} - closing ip6log entry"
        );
        pf::ip6log::close($postdata{'oldip'});
    }

    return (pf::ip6log::open($postdata{'ip'}, $postdata{'mac'}, $postdata{'ip_type'}, $postdata{'lease_length'}));
}

sub unreg_node_for_pid : Public:AllowedAsAction(pid, $pid) {
    my ($class, %postdata) = @_;
    my $logger = pf::log::get_logger();
    my @require = qw(pid);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);
    my $pid = $postdata{'pid'};

    my @node_infos = pf::node::node_view_reg_pid($pid);
    my $count = scalar(@node_infos);
    $logger->info("Unregistering $count node(s) for $pid");

    foreach my $node_info ( @node_infos ) {
        pf::node::node_deregister($node_info->{'mac'});
        pf::enforcement::reevaluate_access( $node_info->{'mac'}, 'manage_deregister' );
    }

    return $count;
}

sub synchronize_locationlog : Public {
    my ( $class, $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $connection_sub_type, $user_name, $ssid ,$stripped_user_name, $realm, $role) = @_;
    my $logger = pf::log::get_logger();

    return (pf::locationlog::locationlog_synchronize($switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $connection_sub_type, $user_name, $ssid, $stripped_user_name, $realm, $role));
}

sub open_iplog : Public {
    my ( $class, $mac, $ip, $lease_length ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::ip4log::open($ip, $mac, $lease_length));
}

sub close_iplog : Public {
    my ( $class, $ip ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::ip4log::close($ip));
}

sub ipset_node_update : Public {
    my ( $class, $oldip, $srcip, $srcmac ) = @_;
    my $logger = pf::log::get_logger();

    return(pf::ipset->update_node($oldip, $srcip, $srcmac));
}

sub firewallsso : Public {
    my ( $class, %postdata ) = @_;
    my @require = qw(method mac ip timeout);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    return pf::firewallsso::do_sso(%postdata);
}

sub ReAssignVlan : Public : Fork {
    my ($class, %postdata )  = @_;
    my @require = qw(connection_type switch mac ifIndex);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    if ( not defined( $postdata{'connection_type'} )) {
        $logger->error("Connection type is unknown. Could not reassign VLAN.");
        return;
    }

    my $switch = pf::SwitchFactory->instantiate( $postdata{'switch'} );
    unless ($switch) {
        $logger->error("switch $postdata{'switch'} not found for ReAssignVlan");
        return;
    }

    sleep $pf::config::Config{'fencing'}{'wait_for_redirect'};

    # SNMP traps connections need to be handled specially to account for port-security etc.
    if ( ($postdata{'connection_type'} & $pf::config::WIRED_SNMP_TRAPS) == $pf::config::WIRED_SNMP_TRAPS ) {
        _reassignSNMPConnections($switch, $postdata{'mac'}, $postdata{'ifIndex'}, $postdata{'connection_type'} );
    }
    elsif ( $postdata{'connection_type'} & $pf::config::WIRED) {
        my ( $switchdeauthMethod, $deauthTechniques )
            = $switch->wiredeauthTechniques( $switch->{_deauthMethod}, $postdata{'connection_type'} );
        $switch->$deauthTechniques( $postdata{'ifIndex'}, $postdata{'mac'} );
    }
    else {
        $logger->error("Connection type is not wired. Could not reassign VLAN.");
    }
}

=head2 ReAssignVlan_in_queue

ReAssignVlan_in_queue is use to localy use ReAssignVlan function in pfqueue to get rid of perl modules that crashed apache

=cut

sub ReAssignVlan_in_queue : Public {
    my ($class, %postdata )  = @_;
    my $client = pf::api::queue->new(queue => 'priority');
    $client->notify( 'ReAssignVlan', %postdata );
}

sub desAssociate : Public : Fork {
    my ($class, %postdata )  = @_;
    my @require = qw(switch mac connection_type ifIndex);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    my $switch = pf::SwitchFactory->instantiate($postdata{'switch'});
    unless ($switch) {
        $logger->error("switch $postdata{'switch'} not found for desAssociate");
        return;
    }

    my ($switchdeauthMethod, $deauthTechniques) = $switch->deauthTechniques($switch->{'_deauthMethod'});

    # sleep long enough to give the device enough time to fetch the redirection page.
    sleep $pf::config::Config{'fencing'}{'wait_for_redirect'};

    $logger->info("[$postdata{'mac'}] DesAssociating mac on switch (".$switch->{'_id'}.")");
    $switch->$deauthTechniques($postdata{'mac'});
}

=head2 desAssociate_in_queue

desAssociate is use to localy use desAssociate function in pfqueue to get rid of perl modules that crashed apache

=cut

sub desAssociate_in_queue : Public {
    my ($class, %postdata )  = @_;
    my $client = pf::api::queue->new(queue => 'priority');
    $client->notify( 'desAssociate', %postdata );
}


sub firewall : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    # verify if firewall rule is ok
    my $inline = new pf::inline::custom();
    $inline->performInlineEnforcement($postdata{'mac'});
}


# Handle connection types $WIRED_SNMP_TRAPS
sub _reassignSNMPConnections {
    my ( $switch, $mac, $ifIndex, $connection_type ) = @_;
    my $logger = pf::log::get_logger();
    # find open non VOIP entries in locationlog. Fail if none found.
    my @locationlog = pf::locationlog::locationlog_view_open_switchport_no_VoIP( $switch->{_id}, $ifIndex );
    unless ( (@locationlog) && ( scalar(@locationlog) > 0 ) && ( $locationlog[0]->{'mac'} ne '' ) ) {
        $logger->warn(
            "received reAssignVlan trap on (".$switch->{'_id'}.") ifIndex $ifIndex but can't determine non VoIP MAC"
        );
        return;
    }

    # case PORTSEC : When doing port-security we need to reassign the VLAN before
    # bouncing the port.
    if ( $switch->isPortSecurityEnabled($ifIndex) ) {
        $logger->info( "security traps are configured on (".$switch->{'_id'}.") ifIndex $ifIndex. Re-assigning VLAN" );

        _node_determine_and_set_into_VLAN( $mac, $switch, $ifIndex, $connection_type );

        # We treat phones differently. We never bounce their ports except if there is an outstanding
        # violation.
        if ( $switch->hasPhoneAtIfIndex($ifIndex)  ) {
            my @violations = pf::violation::violation_view_open_desc($mac);
            if ( scalar(@violations) == 0 ) {
                $logger->warn("VLAN changed and is behind VoIP phone. Not bouncing the port!");
                return;
            }
        }

    } # end case PORTSEC

    $logger->info( "Flipping admin status on switch (".$switch->{'_id'}.") ifIndex $ifIndex. " );
    $switch->bouncePort($ifIndex);
}

=head2 _node_determine_and_set_into_VLAN

Set the vlan for the node on the switch

=cut

sub _node_determine_and_set_into_VLAN {
    my ( $mac, $switch, $ifIndex, $connection_type ) = @_;

    my $role_obj = new pf::role::custom();
    my $args = {
        mac => $mac,
        node_info => pf::node::node_attributes($mac),
        switch => $switch,
        ifIndex => $ifIndex,
        connection_type => $connection_type,
        profile => pf::Connection::ProfileFactory->instantiate($mac),
    };

    my $role = $role_obj->fetchRoleForNode($args);
    my $vlan = $role->{vlan} || $switch->getVlanByName($role->{role});

    my %locker_ref;
    $locker_ref{$switch->{_ip}} = &share({});

    $switch->setVlan(
        $ifIndex,
        $vlan,
        \%locker_ref,
        $mac
    );
}


=head2 violation_delayed_run

runs the delayed violation now

=cut

sub violation_delayed_run : Public {
    my ($self, $violation) = @_;
    pf::violation::_violation_run_delayed($violation);
    return ;
}

=head2 trigger_violation

Trigger a violation

=cut

sub trigger_violation : Public :AllowedAsAction(mac, $mac, tid, TYPEID, type, TYPE) {
    my ($class, %postdata )  = @_;
    my @require = qw(mac tid type);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    return (pf::violation::violation_trigger( { 'mac' => $postdata{'mac'}, 'tid' => $postdata{'tid'}, 'type' => $postdata{'type'} } ));
}

=head2 release_all_violations

Release all violations for a node

=cut

sub release_all_violations : Public:AllowedAsAction($mac){
    my ($class, $mac) = @_;
    my $logger = pf::log::get_logger;
    $mac = pf::util::clean_mac($mac);
    die "Missing MAC address" unless($mac);
    my $closed_violation = 0;
    foreach my $violation (pf::violation::violation_view_open($mac)){
        $logger->info("Releasing violation $violation->{vid} for $mac though release_all_violations");
        if(pf::violation::violation_force_close($mac,$violation->{vid})){
            $closed_violation += 1;
        }
        else {
            $logger->error("Cannot close violation $violation->{vid} for $mac");
        }
    }
    return $closed_violation;
}


=head2 add_node

Modify a node

=cut

sub modify_node : Public :AllowedAsAction(mac, $mac) {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    if (defined($postdata{'unregdate'})) {
        if (pf::util::valid_date($postdata{'unregdate'})) {
            $postdata{'unregdate'} = pf::config::dynamic_unreg_date($postdata{'unregdate'});
        } else {
            $postdata{'unregdate'} = pf::config::access_duration($postdata{'unregdate'});
        }
    }
    pf::node::node_modify($postdata{'mac'}, %postdata);
    return;
}

=head2 register_node

Register a node

=cut

sub register_node : Public :AllowedAsAction(mac, $mac, pid, $pid) {
    my ($class, %postdata )  = @_;
    my @require = qw(mac pid);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    return pf::node::node_register($postdata{'mac'}, $postdata{'pid'}, %postdata);
}

=head2 deregister_node

Deregister a node

=cut

sub deregister_node : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    return pf::node::node_deregister($postdata{'mac'}, %postdata);
}

=head2 register_node_ip

Register a node by IP address

=cut

sub register_node_ip : Public :AllowedAsAction(ip, $ip, pid, $pid) {
    my ($class, %postdata )  = @_;
    my @require = qw(ip pid);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $mac = pf::ip4log::ip2mac($postdata{'ip'});
    die "Cannot find host with IP address $postdata{'ip'}" unless $mac;

    return pf::node::node_register($mac, $postdata{'pid'}, %postdata);
}

=head2 deregister_node_ip

Deregister a node by IP address

=cut

sub deregister_node_ip : Public:AllowedAsAction(ip, $ip) {
    my ($class, %postdata )  = @_;
    my @require = qw(ip);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $mac = pf::ip4log::ip2mac($postdata{'ip'});
    die "Cannot find host with IP address $postdata{'ip'}" unless $mac;

    return pf::node::node_deregister($mac, %postdata);
}

=head2 node_information

Return all the node attributes

=cut

sub node_information : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $node_info = pf::node::node_view($postdata{'mac'});
    return $node_info;
}

sub notify_configfile_changed : Public {
    my ($class, %postdata) = @_;
    my $logger = pf::log::get_logger;
    my @require = qw(server conf_file);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require, \@found);

    # we light expire pfconfig cluster configuration on this server so it uses the distributed configuration
    my $payload = {
        method => "expire",
        namespace => 'config::Cluster',
        light => 1,
    };
    pfconfig::util::fetch_decode_socket(encode_json($payload));

    my $master_server = $ConfigCluster{$postdata{server}};
    die "Master server is not in configuration" unless ($master_server);

    my $apiclient = pf::api::jsonrpcclient->new(proto => 'https', host => $master_server->{management_ip});

    eval {
        my %data = ( conf_file => $postdata{conf_file} );
        my ($result) = $apiclient->call( 'download_configfile', %data );
        pf::util::safe_file_update($postdata{conf_file}, $result);

        $logger->info("Successfully downloaded configuration $postdata{conf_file} from $postdata{server}");
    };
    if($@){
        $logger->error("Couldn't download configuration file $postdata{conf_file} from $postdata{server}. $@");
        die $@;
    }

    return 1;
}

sub download_configfile : Public {
    my ($class, %postdata) = @_;
    my @require = qw(conf_file);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require, \@found);

    die "Config file $postdata{conf_file} doesn't exist" unless(-e $postdata{conf_file});
    my $config = read_file($postdata{conf_file});

    return $config;
}

sub distant_download_configfile : Public {
    my ($class, %postdata) = @_;
    my @require = qw(conf_file from);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require, \@found);

    my $file = $postdata{conf_file};
    my %data = ( conf_file => $file );
    my $apiclient = pf::api::jsonrpcclient->new(host => $postdata{from}, proto => 'https');
    my ($result) = $apiclient->call( 'download_configfile', %data );
    pf::util::safe_file_update($file, $result);
    return 1;
}

our $ALLOWED_PATHS_TO_BE_EMPTIED = qr/^\Q$captiveportal_profile_templates_path\E\/[^\.]/;

our $ALLOWED_DELETED_PATHS = qr/^\Q$captiveportal_profile_templates_path\E\/[^\.]/;

=head2 directory_empty

Empty a directory of all its files

=cut

sub directory_empty : Public {
    my ($class, $dir) = @_;
    die "$dir has invalid characters " if $dir =~ /(\.\.)/;
    die "$dir is not allowed to be empty" unless $dir =~ $ALLOWED_PATHS_TO_BE_EMPTIED;
    pf::util::empty_dir($dir);
}

=head2 delete_files

Delete files

=cut

sub delete_files : Public {
    my ($class, $files) = @_;
    foreach my $file (@$files) {
        die "$file has invalid characters " if $file =~ /(\.\.)/;
        die "$file is not allowed to be deleted" unless $file =~ $ALLOWED_DELETED_PATHS;
    }
    unlink(@$files);
}

sub expire_cluster : Public {
    my ($class, %postdata) = @_;
    my @require = qw(namespace conf_file);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require, \@found);

    my $logger = pf::log::get_logger;

    $postdata{light} = 0;
    expire($class, %postdata);

    my @failed;
    foreach my $server (pf::cluster::enabled_servers()){
        next if($pf::cluster::host_id eq $server->{host});
        my $apiclient = pf::api::jsonrpcclient->new(proto => 'https', host => $server->{management_ip});
        my %data = (
            namespace => $postdata{namespace},
            light => 1
        );
        eval {
            $apiclient->call('expire', %data );
        };

        if($@){
            $logger->error("An error occured while expiring the configuration on $server->{management_ip}. $@");
            push @failed, $server->{host};
            next;
        }

        %data = (
            conf_file => $postdata{conf_file},
            server => $pf::cluster::host_id,
        );

        eval {
            $apiclient->call('notify_configfile_changed', %data);
        };

        if($@){
            $logger->error("An error occured while notifying the change of configuration on $server->{management_ip}. $@");
            push @failed, $server->{host};
            next;
        }

        eval {
            $apiclient->call('set_config_version', version => pf::cluster::get_config_version());
        };

        if($@){
            $logger->error("An error occured while pushing the configuration version ID to $server->{management_ip}. $@");
            push @failed, $server->{host};
            next;
        }
    }

    if(@failed){
        die "Failed to sync configuration on server(s) ".join(',',@failed);
    }

    return 1;
}

sub expire : Public {
    my ($class, %postdata ) = @_;
    my $logger = pf::log::get_logger;
    my @require = qw(namespace light);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require, \@found);

    my $all = $postdata{namespace} eq "__all__" ? 1 : 0;
    if($all){
        pfconfig::manager->new->expire_all($postdata{light});
    }
    else{
        pfconfig::manager->new->expire($postdata{namespace}, $postdata{light});
    }
    # There are currently no errors returned
    return { error => 0 };
}

=head2 add_person

Add a new person

=cut

sub add_person : Public :AllowedAsAction(pid, $pid) {
    my ($class, %params) = @_;
    my @require = qw(pid);
    my @found = grep {exists $params{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);
    my $logger = pf::log::get_logger();
    my $pid    = delete $params{pid};
    my $sendmail = delete $params{sendmail};
    if(pf::person::person_exist($pid)) {
        my $msg = "person $pid already exists\n";
        $logger->error($msg);
        die $msg;
    }
    my $result = pf::person::person_modify($pid, %params);
    unless ($result) {
        my $msg = "Unable to create user $pid\n";
        $logger->error($msg);
        die $msg;
    }
    $logger->info("Created user account $pid.");
    # Add the registration window to the actions
    _update_person_actions(\%params);
    my $password = pf::password::generate($pid, $params{actions}, $params{password});
    unless ($password) {
        my $msg = "Unable to generate password\n";
        $logger->error($msg);
        die $msg;
    }

    return 1;
}

sub _update_person_actions {
    my ($params) = @_;
    $params->{actions} ||= [];
    if(exists $params->{valid_from}) {
        push(@{$params->{actions}}, {type => 'valid_from', value => delete $params->{valid_from}});
    }
    if(exists $params->{expiration} ) {
        push(@{$params->{actions}}, {type => 'expiration', value => delete $params->{expiration}});
    }
    if(exists $params->{access_level} ) {
        push(@{$params->{actions}}, {type => 'set_access_level', value => delete $params->{access_level}});
    }
    if(exists $params->{sponsor} ) {
        push(@{$params->{actions}}, {type => 'mark_as_sponsor', value => delete $params->{sponsor}});
    }
    if(exists $params->{role} ) {
        push(@{$params->{actions}}, {type => 'set_role', value => delete $params->{role}});
    }
    if(exists $params->{access_duration} ) {
        push(@{$params->{actions}}, {type => 'set_access_duration', value => delete $params->{access_duration}});
    }
    if(exists $params->{unreg_date} ) {
        push(@{$params->{actions}}, {type => 'set_unreg_date', value => delete $params->{unreg_date}});
    }
}

=head2 view_person

View a person entry

=cut

sub view_person : Public {
    my ($class,$pid) = @_;
    my $logger = pf::log::get_logger();
    unless(pf::person::person_exist($pid)) {
        my $msg = "person $pid does not exist\n";
        $logger->error($msg);
        die $msg;
    }
    my $person = pf::person::person_view($pid);
    unless ($person) {
        my $msg = "Error retrieving $pid\n";
        $logger->error($msg);
        die $msg;
    }
    return $person;
}

=head2 modify_person

Modify an existing person

=cut

sub modify_person : Public :AllowedAsAction(pid, $pid) {
    my ($class, %params) = @_;
    my @require = qw(pid);
    my @found = grep {exists $params{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);
    my $pid = delete $params{pid};
    my $logger = pf::log::get_logger();
    unless(pf::person::person_exist($pid)) {
        my $msg = "person $pid does not exist\n";
        $logger->error($msg);
        die $msg;
    }
    my $person = pf::person::person_view($pid);
    %params = (%$person,%params);
    _update_person_actions(\%params);
    pf::password::modify_actions( { pid => $pid},$params{actions});
    my $result = pf::person::person_modify($pid, %params);
    return $result;
}

=head2 delete_person

Delete a person

=cut

sub delete_person {
    my ($class,$pid) = @_;
    my $result = pf::person::person_delete($pid);
    return $result;
}

=head2 trigger_scan

Check if we have to launch a scan for the device

=cut

sub trigger_scan :Public :Fork :AllowedAsAction($ip, mac, $mac, net_type, TYPE) {
    my ($class, %postdata )  = @_;
    my @require = qw(ip mac net_type);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    return unless scalar keys %pf::config::ConfigScan;
    my $logger = pf::log::get_logger();
    # post_registration (production vlan)
    # We sleep until (we hope) the device has had time issue an ACK.
    if (pf::util::is_prod_interface($postdata{'net_type'})) {
        my $profile = pf::Connection::ProfileFactory->instantiate($postdata{'mac'});
        my $scanner = $profile->findScan($postdata{'mac'});
        if (defined($scanner) && pf::util::isenabled($scanner->{'_post_registration'})) {
            pf::violation::violation_add( $postdata{'mac'}, $pf::constants::scan::POST_SCAN_VID );
        }
        my $top_violation = pf::violation::violation_view_top($postdata{'mac'});
        # get violation id
        my $vid = $top_violation->{'vid'};
        return if not defined $vid;
        sleep $pf::config::Config{'fencing'}{'wait_for_redirect'};
        pf::scan::run_scan($postdata{'ip'}, $postdata{'mac'}) if  ($vid eq $pf::constants::scan::POST_SCAN_VID);
    }
    else {
        my $profile = pf::Connection::ProfileFactory->instantiate($postdata{'mac'});
        my $scanner = $profile->findScan($postdata{'mac'});
        # pre_registration
        if (defined($scanner) && pf::util::isenabled($scanner->{'_pre_registration'})) {
            pf::violation::violation_add( $postdata{'mac'}, $pf::constants::scan::PRE_SCAN_VID );
        }
        my $top_violation = pf::violation::violation_view_top($postdata{'mac'});
        my $vid = $top_violation->{'vid'};
        return if not defined $vid;
        sleep $pf::config::Config{'fencing'}{'wait_for_redirect'};
        pf::scan::run_scan($postdata{'ip'}, $postdata{'mac'}) if  ($vid eq $pf::constants::scan::PRE_SCAN_VID || $vid eq $pf::constants::scan::SCAN_VID);
    }
    return;
}

=head2 start_scan

Start a scan for a device

=cut

sub start_scan : Public {
    my ($self, %postdata) = @_;
    my @require = qw(ip);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    pf::scan::run_scan($postdata{'ip'}, $postdata{'mac'});
}

=head2 close_violation

Close a violation

=cut

sub close_violation :Public :AllowedAsAction(mac, $mac, vid , VID) {
    my ($class, %postdata )  = @_;
    my @require = qw(mac vid);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    if(defined($postdata{force}) && $postdata{force}) {
        return pf::violation::violation_force_close($postdata{'mac'}, $postdata{'vid'})
    }
    else {
        my $grace = pf::violation::violation_close($postdata{'mac'}, $postdata{'vid'});
        if ( $grace == -1 ) {
            $logger->warn("Problem trying to close violation");
            return $pf::config::FALSE;
        }
        return $pf::config::TRUE;
    }
}

=head2 dynamic_register_node

Register a node based on mac username
Per example fetch the current user connected on a device through a WMI scan and register it.

=cut

sub dynamic_register_node : Public :AllowedAsAction(mac, $mac, username, $username) {
    my ($class, %postdata )  = @_;
    my @require = qw(mac username);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();
    my $profile = pf::Connection::ProfileFactory->instantiate($postdata{'mac'});
    my $node_info = pf::node::node_view($postdata{'mac'});
    # We try this although the realm is not mandatory in case it proves to be useful in the future
    my @sources = $profile->getFilteredAuthenticationSources($postdata{'username'}, $postdata{'realm'});
    my $stripped_user = '';

    my $params = {
        username => $postdata{'username'},
        connection_type => $node_info->{'last_connection_type'},
        SSID => $node_info->{'last_ssid'},
        stripped_user_name => $stripped_user,
        realm => $node_info->{'realm'},
        context => $pf::constants::realm::RADIUS_CONTEXT,
    };

    my $source;
    my $matched = pf::authentication::match2([@sources], $params);
    unless ($matched) {
        $logger->warn("Did not find any actions to match");
        return;
    }
    my $values = $matched->{values};
    my $role = $values->{$Actions::SET_ROLE};
    my $unregdate = $values->{$Actions::SET_UNREG_DATE};
    my $time_balance =  $values->{$Actions::SET_TIME_BALANCE};
    my $bandwidth_balance =  $values->{$Actions::SET_BANDWIDTH_BALANCE};
    if (defined $unregdate) {
        my %info = (
            'unregdate' => $unregdate,
            'category' => $role,
            'autoreg' => 'no',
            'pid' => $postdata{'username'},
            'source'  => \$source,
            'portal'  => $profile->getName,
            'status' => 'reg',
        );
        if (defined $role) {
            %info = (%info, (category => $role));
        }
        if (defined $time_balance) {
            %info = (%info, (time_balance => pf::util::normalize_time($time_balance)));
        }
        if (defined $bandwidth_balance) {
            %info = (%info, (bandwidth_balance => pf::util::unpretty_bandwidth($bandwidth_balance)));
        }
        pf::node::node_register($postdata{'mac'}, $postdata{'username'}, %info);
        pf::enforcement::reevaluate_access( $postdata{'mac'}, 'manage_register' );
    }
}

=head2 fingerbank_process

=cut

sub fingerbank_process : Public {
    my ( $class, $mac ) = @_;
    pf::fingerbank::process($mac);
}

=head2 fingerbank_update_component

=cut

sub fingerbank_update_component : Public : Fork {
    my ( $class, %postdata ) = @_;
    my @require = qw(action);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,\@found);

    if(defined($postdata{'fork_to_queue'}) && $postdata{'fork_to_queue'}) {
        delete $postdata{'fork_to_queue'};
        pf::log::get_logger->info("Sending fingerbank component update to local queue.");
        pf::api::queue->new->notify('fingerbank_update_component', %postdata);
        return (200, "Sent to local queue");
    }

    my $action = $pf::fingerbank::ACTION_MAP{$postdata{action}};
    my ($status, $status_msg);
    if(defined($action)){
        ( $status, $status_msg ) = $action->();
        $status_msg //= "";
    }
    else {
        $status = 404;
        $status_msg = "Couldn't find action ".$postdata{action};
    }

    if(defined($postdata{email_admin}) && $postdata{email_admin}){
        pf::config::util::pfmailer(( subject => 'Fingerbank - '.$postdata{action}.' status', message => $status_msg ));
    }

    return ($status, $status_msg);
}

=head2 throw

Method throw for testing purposes

=cut

sub throw : Public {
    die "This will always die\n";
}

=head2 detect_computername_change

Will determine if a hostname has changed from what is currently stored in the DB
Will try to trigger a violation with the trigger internal::hostname_change

=cut

sub detect_computername_change : Public {
    my ( $class, $mac, $new_computername ) = @_;
    my $logger = pf::log::get_logger;
    my $node_attributes = pf::node::node_attributes($mac);

    if(defined($node_attributes->{computername}) && $node_attributes->{computername}){
        if($node_attributes->{computername} ne $new_computername){
            $logger->warn(
              "Computername change detected ".
              "( ".$node_attributes->{computername}." -> $new_computername ).".
              "Possible MAC spoofing.");

            pf::violation::violation_trigger( { 'mac' => $mac, 'tid' => "hostname_change", 'type' => "internal" } );
            return 1;
        }
    }
    return 0;
}

=head2 reevaluate_access

Reevaluate the access of the mac address.

=cut

sub reevaluate_access : Public :AllowedAsAction(mac, $mac, reason, $reason) {
    my ($class, %postdata )  = @_;
    my @require = qw(mac reason);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,\@found);

    my $logger = pf::log::get_logger();

    pf::enforcement::reevaluate_access( $postdata{'mac'}, $postdata{'reason'} );
}

=head2 process_dhcpv4

Processes a DHCPv4 request through the pf::dhcp::processor_v4 module
The UDP payload must be base 64 encoded.

=cut

sub process_dhcpv4 : Public {
    my ($class, %postdata) = @_;
    my @require = qw(src_mac src_ip dest_mac dest_ip is_inline_vlan interface interface_ip interface_vlan net_type);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,\@found);

    my $dhcpv4Processor = pf::dhcp::processor_v4->new(%postdata);
    $dhcpv4Processor->process_packet();

    return $pf::config::TRUE;
}

=head2 process_dhcpv6

Processes a DHCPv6 udp payload to extract the fingerprint and enterprise ID.
It then uses these in Fingerbank and records them in the database.

The UDP payload must be base 64 encoded.

=cut

sub process_dhcpv6 : Public {
    my ( $class, $udp_payload ) = @_;

    my $dhcpv6Processor = pf::dhcp::processor_v6->new();
    $dhcpv6Processor->process_packet($udp_payload);
}

=head2 copy_directory

Copy a directory on this server

=cut

sub copy_directory : Public {
    my ($class, $source_dir, $dest_dir) = @_;
    return dircopy($source_dir, $dest_dir);
}

=head2 metadefender_process

=cut

sub metadefender_process : Public {
    my ( $class, $data ) = @_;

    my $metadefender_scan_result_id = pf::metadefender->hash_lookup($data);
    return if !defined($metadefender_scan_result_id);

    my $violation_note = "Filename: " . $data->{'filename'} . "\n From host: " . $data->{'http_host'};
    pf::violation::violation_trigger( { 'mac' => $data->{'mac'}, 'tid' => $metadefender_scan_result_id, 'type' => "metadefender", 'notes' => $violation_note } );
}

sub rest_ping :Public :RestPath(/rest/ping){
    my ($class, $args) = @_;
    return "pong - ".$args->{message};
}

=head2 radius_rest_authorize

RADIUS authorize method that uses REST

=cut

sub radius_rest_authorize :Public :RestPath(/radius/rest/authorize) {
    my ($class, $radius_request) = @_;
    my $timer = pf::StatsD::Timer->new();
    my $logger = pf::log::get_logger();

    my %remapped_radius_request = %{pf::radius::rest::format_request($radius_request)};

    my $return;

    if (pf::util::valid_mac($remapped_radius_request{'Calling-Station-Id'})) {
        $return = $class->radius_authorize(%remapped_radius_request);
    } else {
        $return = $class->radius_switch_access(%remapped_radius_request);
    }

    # This will die with the proper code if it is a deny
    $return = pf::radius::rest::format_response($return);

    return $return;
}

=head2 radius_rest_switch_authorize

RADIUS switch authorize method that uses REST

=cut

sub radius_rest_switch_authorize :Public :RestPath(/radius/rest/switch/authorize) {
    my ($class, $radius_request) = @_;
    my $timer = pf::StatsD::Timer->new();
    my $logger = pf::log::get_logger();

    my %remapped_radius_request = %{pf::radius::rest::format_request($radius_request)};

    my $return = $class->radius_switch_access(%remapped_radius_request);

    # This will die with the proper code if it is a deny
    $return = pf::radius::rest::format_response($return);

    return $return;
}

=head2 radius_rest_accounting

RADIUS accounting method that uses REST

=cut

sub radius_rest_accounting :Public :RestPath(/radius/rest/accounting) {
    my ($class, $radius_request) = @_;
    my $timer = pf::StatsD::Timer->new();
    my $logger = pf::log::get_logger();

    my %remapped_radius_request = %{pf::radius::rest::format_request($radius_request)};

    my $return = $class->handle_accounting_metadata(%remapped_radius_request);

    my $radius = new pf::radius::custom();
    eval {
        $return = $radius->accounting(\%remapped_radius_request);
    };
    if ($@) {
        $logger->error("radius accounting failed with error: $@");
    }

    # This will die with the proper code if it is a deny
    $return = pf::radius::rest::format_response($return);

    return $return;
}


sub handle_accounting_metadata : Public {
    my ($class, %RAD_REQUEST) = @_;
    my $logger = pf::log::get_logger();
    $logger->debug("Entering handling of accounting metadata");
    my $client = pf::client::getClient();

    my $return = [ $RADIUS::RLM_MODULE_OK, ('Reply-Message' => "Accounting OK") ];
    my $mac = pf::util::clean_mac($RAD_REQUEST{'Calling-Station-Id'});
    if ($RAD_REQUEST{'Acct-Status-Type'} == $ACCOUNTING::START) {
        #
        # Updating location log in on initial ('Start') accounting run.
        #
        $logger->info("Updating locationlog from accounting request");
        $client->notify("radius_update_locationlog", %RAD_REQUEST);
    }

    if ($RAD_REQUEST{'Acct-Status-Type'} != $ACCOUNTING::STOP){
        # Tracking IP address.
        if(pf::util::isenabled($pf::config::Config{advanced}{update_iplog_with_accounting})){
            $logger->info("Updating iplog from accounting request");
            $client->notify("update_ip4log", mac => $mac, ip => $RAD_REQUEST{'Framed-IP-Address'}) if ($RAD_REQUEST{'Framed-IP-Address'} );
        }
        else {
            pf::log::get_logger->debug("Not handling iplog update because we're not configured to do so on accounting packets.");
        }
    }
    if ($RAD_REQUEST{'Acct-Status-Type'} == $ACCOUNTING::STOP){
        if (pf::util::isenabled($pf::config::Config{advanced}{unreg_on_accounting_stop})) {
            $client->notify("deregister_node", mac => $mac);
        }
    }
    $client->notify("firewallsso_accounting", %RAD_REQUEST);

    return $return;
}

=head2 firewallsso_accounting

Update the firewall sso based on radius accounting

=cut

sub firewallsso_accounting : Public {
    my ($class, %RAD_REQUEST) = @_;
    my $logger = pf::log::get_logger();
    if ($RAD_REQUEST{'Calling-Station-Id'} && $RAD_REQUEST{'Framed-IP-Address'} && pf::util::isenabled($pf::config::Config{advanced}{sso_on_accounting})) {
        my $mac = pf::util::clean_mac($RAD_REQUEST{'Calling-Station-Id'});
        my $node = pf::node::node_attributes($mac);
        my $ip = $RAD_REQUEST{'Framed-IP-Address'};
        my $firewallsso_method = "Stop";
        my $timeout = '3600'; #Default to 1 hour
        my $client = pf::client::getClient();

        if ($node->{status} eq $pf::node::STATUS_REGISTERED) {
            $firewallsso_method = "Update";
            if ($node->{unregdate} ne '0000-00-00 00:00:00') {
                my $time = DateTime::Format::MySQL->parse_datetime($node->{unregdate});
                $time->set_time_zone("local");
                my $now = DateTime->now(time_zone => "local");
                $timeout = $time->epoch - $now->epoch;
            }
            my $oldip  = pf::ip4log::mac2ip($mac);
            if ( $oldip && $oldip ne $ip ) {
                $client->notify( 'firewallsso', (method => 'Stop', mac => $mac, ip => $oldip, timeout => undef) );
            }
        }

        $firewallsso_method = ($RAD_REQUEST{'Acct-Status-Type'} == $ACCOUNTING::STOP) ? "Stop" : "Update";

        $logger->warn("Firewall SSO Notify");
        $client->notify( 'firewallsso', (method => $firewallsso_method, mac => $mac, ip => $ip, timeout => $timeout) );
    }
}

=head2 services_status

Returns a hash of the managed services along with their status (0 means dead, otherwise it is the PID of the process)

=cut

sub services_status : Public {
    my ($class, $services) = @_;
    my @managers = pf::services::getManagers($services);

    my $statuses = {};
    foreach my $manager (@managers){
        if($manager->isManaged) {
            $statuses->{$manager->name} = $manager->status(1);
        }
    }
    return $statuses;
}

=head2 get_config_version

Get the configuration version

=cut

sub get_config_version :Public {
    my ($class) = @_;
    return { version => pf::cluster::get_config_version() };
}

=head2 set_config_version

Set the configuration version

=cut

sub set_config_version :Public {
    my ($class, %postdata) = @_;
    my @require = qw(version);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,\@found);

    return pf::cluster::set_config_version($postdata{version});
}

=head2 sync_config_as_master

Sync the configuration to the cluster members using this server as the master

=cut

sub sync_config_as_master :Public {
    my ($class) = @_;
    pf::cluster::sync_config_as_master();
}

=head2 chi_cache_clear

Clear a namespace in the CHI cache

=cut

sub chi_cache_clear : Public {
    my ($class, $namespace) = @_;
    my $cache = pf::CHI->new( namespace => $namespace );
    pf::log::get_logger->info("Clearing CHI cache for namespace $namespace");
    return $cache->clear();
}

=head2 enableMABFloatingInQueue

Call enableMABFloating in the local queue

=cut

sub enableMABFloatingInQueue : Public {
    my ( $class, %postdata ) = @_;
    my $logger = pf::log::get_logger;

    my $client = pf::api::queue->new(queue => 'general');
    $client->notify( 'enableMABFloating', %postdata );
}

=head2 disableMABConfigInQueue

Call disableMABFloating in the local queue

=cut

sub disableMABFloatingInQueue : Public {
    my ( $class, %postdata ) = @_;
    my $logger = pf::log::get_logger;

    my $client = pf::api::queue->new(queue => 'general');
    $client->notify( 'disableMABFloating', %postdata );
}

=head2 enableMABFloating

Enable the MAB floating device mode on a switch port

=cut

sub enableMABFloating : Public {
    my ( $class, %postdata ) = @_;
    my $logger = pf::log::get_logger;

    my $switch = pf::SwitchFactory->instantiate( $postdata{'switch'} );
    unless ($switch) {
        $logger->error("switch $postdata{'switch'} not found for enableMABFloating");
        return;
    }
    $switch->enableMABFloatingDevice($postdata{ifIndex});
}

=head2 disableMABFloating

Disable the MAB floating device mode on a switch port

=cut

sub disableMABFloating : Public {
    my ( $class, %postdata ) = @_;
    my $logger = pf::log::get_logger;

    my $switch = pf::SwitchFactory->instantiate( $postdata{'switch'} );
    unless ($switch) {
        $logger->error("switch $postdata{'switch'} not found for disableMABFloating");
        return;
    }
    $switch->disableMABFloatingDevice($postdata{ifIndex});
}

=head2 queue_job

Submit a job to the queue

=cut

sub queue_job : Public {
    my ($class, $queue, $job_name, @args) = @_;
    my $client = pf::api::queue->new(queue => $queue);
    $client->notify($job_name, @args );
}

=head2 populate_ntlm_cache

Called in order to populate the NTLM authentication cache for all valid domain users

=cut

sub populate_ntlm_cache : Public {
    my ($class, $domain) = @_;
    
    my ($result, $msg) = pf::domain::ntlm_cache::populate_ntlm_redis_cache($domain);
    unless($result) {
        pf::log::get_logger->error("Couldn't update NTLM cache for domain $domain: $msg");
        pf::config::util::pfmailer(( subject => "Failed to build NTLM cache for domain $domain", message => "Failure to build the NTLM cache due to '$msg'. Please check server side logs for more details." ));
    }
}

=head2 cache_user_ntlm

Called in order to populate the NTLM authentication cache with a single user

=cut

sub cache_user_ntlm {
    my ($class, $domain, $username) = @_;

    my ($result, $msg) = pf::domain::ntlm_cache::cache_user($domain, $username);
    pf::log::get_logger->error("Couldn't cache user: '$msg'") unless($result);

    return $result;
}

=head2 queue_stats

queue_stats

=cut

sub queue_stats : Public {
    my ($class) = @_;
    return pf::pfqueue::stats->new->stats_data;
}

=head2 update_role_configuration

Update the parameters of a role

=cut

sub update_role_configuration : Public :AllowedAsAction(role, $role) {
    my ($class, %postdata )  = @_;
    my @require = qw(role);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();
    my $role = delete $postdata{'role'};

    my $tc_cs = pf::ConfigStore::TrafficShaping->new;
    if ($postdata{'upload'} == 0 && $postdata{'download'} == 0) {
        $tc_cs->remove($role);
    }
    if ($postdata{'upload'} && $postdata{'download'}) {
        $tc_cs->update_or_create($role, {upload => $postdata{'upload'}, download => $postdata{'download'}});
    }
    $tc_cs->commit();
    delete $postdata{'upload'};
    delete $postdata{'download'};

    my $hash_ref = {};
    $hash_ref = \%postdata;

    my $role_cs = pf::ConfigStore::Roles->new;
    $role_cs->update_or_create($role, $hash_ref);

    $role_cs->commit();
    return $pf::config::TRUE;
}


=head2 role_detail

return the detail of a role

=cut

sub role_detail : Public :AllowedAsAction(role, $role) {
    my ($class, %postdata )  = @_;
    my @require = qw(role);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    my $role_cs = pf::ConfigStore::Roles->new;
    my $tc_cs = pf::ConfigStore::TrafficShaping->new;

    if (defined($tc_cs->read($postdata{'role'}))) {
        return merge($role_cs->read($postdata{'role'}), $tc_cs->read($postdata{'role'}));
    } else {
        return $role_cs->read($postdata{'role'});
    }
}

=head2

return the list of the roles

=cut

sub roles_list : Public {
    my ($class, %postdata )  = @_;

    my $role_cs = pf::ConfigStore::Roles->new;
    my $roles = $role_cs->readAll("name");
    my @role_list;
    foreach my $role (@{$roles}) {
        push @role_list, {'name' => $role->{'name'}};
    }
    return @role_list;
}

=head2 queue_submit

queue_submit

=cut

sub queue_submit :Public {
    my ($class, $queue, $task, $data, $expire_in) = @_;
    my $producer = pf::pfqueue::producer::redis->new;
    my $id = $producer->submit($queue, $task, $data, $expire_in);
    return $id;
}

=head2 queue_submit_delayed

queue_submit_delayed

=cut

sub queue_submit_delayed :Public {
    my ($class, $queue, $task_type, $delay, $task_data, $expire_in) = @_;
    my $producer = pf::pfqueue::producer::redis->new;
    my $id = $producer->submit_delayed($queue, $queue, $task_type, $delay, $task_data, $expire_in);
    return $id;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

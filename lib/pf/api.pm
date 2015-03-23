package pf::api;
=head1 NAME

pf::api RPC methods exposing PacketFence features

=cut

=head1 DESCRIPTION

pf::api

=cut

use strict;
use warnings;

use base qw(pf::api::attributes);
use threads::shared;
use pf::log();
use pf::authentication();
use pf::config();
use pf::config::cached;
use pf::ConfigStore::Interface();
use pf::ConfigStore::Pf();
use pf::iplog();
use pf::Portal::ProfileFactory();
use pf::radius::custom();
use pf::violation();
use pf::soh::custom();
use pf::util();
use pf::node();
use pf::locationlog();
use pf::ipset();
use pfconfig::util;
use pfconfig::manager;
use pf::api::jsonrpcclient;
use pf::cluster;
use JSON;
use pf::file_paths;

use List::MoreUtils qw(uniq);
use NetAddr::IP;
use pf::factory::firewallsso;

use pf::scan();
use pf::person();
use pf::lookup::person();
use pf::enforcement();
use pf::password();
use pf::web::guest();

sub event_add : Public {
    my ($class, $date, $srcip, $type, $id) = @_;
    my $logger = pf::log::get_logger();
    $logger->info("violation: $id - IP $srcip");

    # fetch IP associated to MAC
    my $srcmac = pf::iplog::ip2mac($srcip);
    if ($srcmac) {

        # trigger a violation
        pf::violation::violation_trigger($srcmac, $id, $type);

    } else {
        $logger->info("violation on IP $srcip with trigger ${type}::${id}: violation not added, can't resolve IP to mac !");
        return(0);
    }
    return (1);
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

sub soh_authorize : Public {
    my ($class, %radius_request) = @_;
    my $logger = pf::log::get_logger();

    my $soh = pf::soh::custom->new();
    my $return;
    eval {
      $return = $soh->authorize(\%radius_request);
    };
    if ($@) {
      $logger->error("soh authorize failed with error: $@");
    }
    return $return;
}

sub update_iplog : Public {
    my ($class, %postdata) = @_;
    my @require = qw(mac ip);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    $postdata{'oldip'}  = pf::iplog::mac2ip($postdata{'mac'}) if (!defined($postdata{'oldip'}));
    $postdata{'oldmac'} = pf::iplog::ip2mac($postdata{'ip'}) if (!defined($postdata{'oldmac'}));

    if ( $postdata{'oldmac'} && $postdata{'oldmac'} ne $postdata{'mac'} ) {
        $logger->info(
            "oldmac ($postdata{'oldmac'}) and newmac ($postdata{'mac'}) are different for $postdata{'ip'} - closing iplog entry"
        );
        pf::iplog::close($postdata{'ip'});
    } elsif ($postdata{'oldip'} && $postdata{'oldip'} ne $postdata{'ip'}) {
        $logger->info(
            "oldip ($postdata{'oldip'}) and newip ($postdata{'ip'}) are different for $postdata{'mac'} - closing iplog entry"
        );
        pf::iplog::close($postdata{'oldip'});
    }

    return (pf::iplog::open($postdata{'ip'}, $postdata{'mac'}, $postdata{'lease_length'}));
}

sub unreg_node_for_pid : Public {
    my ($class, %postdata) = @_;
    my $logger = pf::log::get_logger();
    my @require = qw(pid);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    my @node_infos =  pf::node::node_view_reg_pid($postdata{'pid'});
    $logger->info("Unregistering ".scalar(@node_infos)." node(s) for ".$postdata{'pid'});

    foreach my $node_info ( @node_infos ) {
        pf::node::node_deregister($node_info->{'mac'});
    }

    return 1;
}

sub synchronize_locationlog : Public {
    my ( $class, $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $user_name, $ssid ,$stripped_user_name, $realm) = @_;
    my $logger = pf::log::get_logger();

    return (pf::locationlog::locationlog_synchronize($switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $voip_status, $connection_type, $user_name, $ssid, $stripped_user_name, $realm));
}

sub insert_close_locationlog : Public {
    my ($class, $switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $user_name, $ssid, $stripped_user_name, $realm);
    my $logger = pf::log::get_logger();

    return(pf::locationlog::locationlog_insert_closed($switch, $switch_ip, $switch_mac, $ifIndex, $vlan, $mac, $connection_type, $user_name, $ssid, $stripped_user_name, $realm));
}

sub open_iplog : Public {
    my ( $class, $mac, $ip, $lease_length ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::iplog::open($ip, $mac, $lease_length));
}

sub close_iplog : Public {
    my ( $class, $ip ) = @_;
    my $logger = pf::log::get_logger();

    return (pf::iplog::close($ip));
}

sub ipset_node_update : Public {
    my ( $class, $oldip, $srcip, $srcmac ) = @_;
    my $logger = pf::log::get_logger();

    return(pf::ipset::update_node($oldip, $srcip, $srcmac));
}

sub firewallsso : Public {
    my ($class, %postdata) = @_;
    my @require = qw(method mac ip timeout);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    foreach my $firewall_conf ( sort keys %pf::config::ConfigFirewallSSO ) {
        my $firewall = pf::factory::firewallsso->new($firewall_conf);
        $firewall->action($firewall_conf,$postdata{'method'},$postdata{'mac'},$postdata{'ip'},$postdata{'timeout'});
    }
    return $pf::config::TRUE;
}


sub ReAssignVlan : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(connection_type switch mac ifIndex);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

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

    sleep $pf::config::Config{'trapping'}{'wait_for_redirect'};

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

sub desAssociate : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(switch mac connection_type ifIndex);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    my $switch = pf::SwitchFactory->instantiate($postdata{'switch'});
    unless ($switch) {
        $logger->error("switch $postdata{'switch'} not found for desAssociate");
        return;
    }

    my ($switchdeauthMethod, $deauthTechniques) = $switch->deauthTechniques($switch->{'_deauthMethod'});

    # sleep long enough to give the device enough time to fetch the redirection page.
    sleep $pf::config::Config{'trapping'}{'wait_for_redirect'};

    $logger->info("[$postdata{'mac'}] DesAssociating mac on switch (".$switch->{'_id'}.")");
    $switch->$deauthTechniques($postdata{'mac'});
}

sub firewall : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

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
            "[$mac] received reAssignVlan trap on (".$switch->{'_id'}.") ifIndex $ifIndex but can't determine non VoIP MAC"
        );
        return;
    }

    # case PORTSEC : When doing port-security we need to reassign the VLAN before
    # bouncing the port.
    if ( $switch->isPortSecurityEnabled($ifIndex) ) {
        $logger->info( "[$mac] security traps are configured on (".$switch->{'_id'}.") ifIndex $ifIndex. Re-assigning VLAN" );

        _node_determine_and_set_into_VLAN( $mac, $switch, $ifIndex, $connection_type );

        # We treat phones differently. We never bounce their ports except if there is an outstanding
        # violation.
        if ( $switch->hasPhoneAtIfIndex($ifIndex)  ) {
            my @violations = pf::violation::violation_view_open_desc($mac);
            if ( scalar(@violations) == 0 ) {
                $logger->warn("[$mac] VLAN changed and is behind VoIP phone. Not bouncing the port!");
                return;
            }
        }

    } # end case PORTSEC

    $logger->info( "[$mac] Flipping admin status on switch (".$switch->{'_id'}.") ifIndex $ifIndex. " );
    $switch->bouncePort($ifIndex);
}

=head2 _node_determine_and_set_into_VLAN

Set the vlan for the node on the switch

=cut

sub _node_determine_and_set_into_VLAN {
    my ( $mac, $switch, $ifIndex, $connection_type ) = @_;

    my $vlan_obj = new pf::vlan::custom();

    my ($vlan,$wasInline) = $vlan_obj->fetchVlanForNode($mac, $switch, $ifIndex, $connection_type);

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

sub trigger_violation : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac tid type);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    return (pf::violation::violation_trigger($postdata{'mac'}, $postdata{'tid'}, $postdata{'type'}));
}


=head2 add_node

Modify a node

=cut

sub modify_node : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

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

sub register_node : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac pid);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    pf::node::node_register($postdata{'mac'}, $postdata{'pid'}, %postdata);
    return;
}

=head2 deregister_node

Deregister a node

=cut

sub deregister_node : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    pf::node::node_deregister($postdata{'mac'}, %postdata);
    return;
}

=head2 node_information

Return all the node attributes

=cut

sub node_information : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    my $node_info = pf::node::node_view($postdata{'mac'});
    return $node_info;
}

sub notify_configfile_changed : Public {
    my ($class, %postdata) = @_;
    my $logger = pf::log::get_logger;
    my @require = qw(server conf_file);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require, \@found);

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
        open(my $fh, '>', $postdata{conf_file}) or die "Cannot open file $postdata{conf_file} for writing. This is excessively bad. Run '/usr/local/pf/bin/pfcmd fixpermissions'";
        print $fh $result;
        close($fh);
        use pf::config::cached;
        pf::config::cached::updateCacheControl();
        pf::config::cached::ReloadConfigs(1);

        $logger->info("Successfully downloaded configuration $postdata{conf_file} from $postdata{server}");
    };
    if($@){
        $logger->error("Couldn't download configuration file $postdata{conf_file} from $postdata{server}. $@");
    }

    return 1;
}

sub download_configfile : Public {
    my ($class, %postdata) = @_;
    my @require = qw(conf_file);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require, \@found);

    use File::Slurp;
    die "Config file $postdata{conf_file} doesn't exist" unless(-e $postdata{conf_file});
    my $config = read_file($postdata{conf_file});

    return $config;
}

sub distant_download_configfile : Public {
    my ($class, %postdata) = @_;
    my @require = qw(conf_file from);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require, \@found);

    my $file = $postdata{conf_file};
    my %data = ( conf_file => $file );
    my $apiclient = pf::api::jsonrpcclient->new(host => $postdata{from}, proto => 'https');
    my ($result) = $apiclient->call( 'download_configfile', %data );
    open(my $fh, '>', $file);
    print $fh $result;
    close($fh);
    `chown pf.pf $file`;

    return 1;

}

sub expire_cluster : Public {
    my ($class, %postdata) = @_;
    my @require = qw(namespace conf_file);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require, \@found);

    my $logger = pf::log::get_logger;

    $postdata{light} = 0;
    expire($class, %postdata);

    foreach my $server (@cluster_servers){
        next if($host_id eq $server->{host});
        my $apiclient = pf::api::jsonrpcclient->new(proto => 'https', host => $server->{management_ip});
        my %data = (
            namespace => $postdata{namespace},
            light => 1
        );
        eval {
            $apiclient->call('expire', %data );
        };

        if($@){
            $logger->error("An error occured while expiring the configuration on $server->{management_ip}. $@")
        }

        %data = (
            conf_file => $postdata{conf_file},
            server => $host_id,
        );

        eval {
            $apiclient->call('notify_configfile_changed', %data);
        };

        if($@){
            $logger->error("An error occured while notifying the change of configuration on $server->{management_ip}. $@")
        }
    }
    return 1;
}

sub expire : Public {
    my ($class, %postdata ) = @_;
    my $logger = pf::log::get_logger;
    my @require = qw(namespace light);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require, \@found);

    # this is to detect failures in the light expire which has the most chances of failing since it requires the pfconfig service to be alive
    my $error = 0;
    if($postdata{light}){
        my $payload = {
          method => "expire",
          namespace => $postdata{namespace},
          light => $postdata{light},
        };

        my $result = pfconfig::util::fetch_decode_socket(encode_json($payload));
        unless ( $result->{status} eq "OK." ) {
            $logger->error("Couldn't light expire namespace $postdata{namespace}");
            $error = 1;
        }
    }
    else {
        my $all = $postdata{namespace} eq "__all__" ? 1 : 0;
        if($all){
            pfconfig::manager->new->expire_all();
        }
        else{
            pfconfig::manager->new->expire($postdata{namespace});
        }
    }
    return { error => $error };
}

=head2 validate_argv

Test if the required arguments are provided

=cut

sub validate_argv {
    my ($require, $found) = @_;
    my $logger = pf::log::get_logger();

    if (!(@{$require} == @{$found})) {
        my %diff;
        @diff{ @{$require} } = @{$require};
        delete @diff{ @{$found} };
        $logger->error("Missing argument ". join(',',keys %diff) ." for the function ".whowasi());
        return 0;
    }
    return 1;
}


=head2 add_person

Add a new person

=cut

sub add_person : Public {
    my ($class, %params) = @_;
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
    push(@{$params{actions}}, {type => 'valid_from', value => $params{valid_from}});
    push(@{$params{actions}}, {type => 'expiration', value => $params{expiration}});
    my $password = pf::password::generate($pid, $params{actions}, $params{password});
    unless ($password) {
        my $msg = "Unable to generate password\n";
        $logger->error($msg);
        die $msg;
    }

    return 1;
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

sub modify_person : Public {
    my ($class, %params) = @_;
    my $pid = delete $params{pid};
    my $result = pf::person::person_modify($pid, %params);
    return $result;
}


=head2 whowasi

Return the parent function name

=cut

sub whowasi { ( caller(2) )[3] }

=head2 trigger_scan

Check if we have to launch a scan for the device

=cut

sub trigger_scan : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(ip mac net_type);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);


    my $logger = pf::log::get_logger();
    # post_registration (production vlan)
    if (pf::util::is_prod_interface($postdata{'net_type'})) {
        my $top_violation = pf::violation::violation_view_top($postdata{'mac'});
        # get violation id
        my $vid = $top_violation->{'vid'};
        sleep $pf::config::Config{'trapping'}{'wait_for_redirect'};
        pf::scan::run_scan($postdata{'ip'}, $postdata{'mac'}) if  ($vid eq $pf::constants::scan::POST_SCAN_VID);
    }
    # pre_registration
    else {
        my $profile = pf::Portal::ProfileFactory->instantiate($postdata{'mac'});
        my $scanner = $profile->findScan($postdata{'mac'});
        if ($scanner && pf::util::isenabled($scanner->{'pre_registration'})) {
            pf::violation::violation_add( $postdata{'mac'}, $pf::constants::scan::PRE_SCAN_VID );
            my $top_violation = pf::violation::violation_view_top($postdata{'mac'});
            my $vid = $top_violation->{'vid'};
            sleep $pf::config::Config{'trapping'}{'wait_for_redirect'};
            pf::scan::run_scan($postdata{'ip'}, $postdata{'mac'}) if  ($vid eq $pf::constants::scan::PRE_SCAN_VID);
        }
    }
    return;
}

=head2 close_violation

Close a violation

=cut

sub close_violation : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac vid);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();

    my $grace = pf::violation::violation_close($postdata{'mac'}, $postdata{'vid'});
    if ( $grace == -1 ) {
        $logger->warn("Problem trying to close scan violation");
    }
    return;
}

=head2 dynamic_register_node

Register a node based on mac username
Per example fetch the current user connected on a device through a WMI scan and register it.

=cut

sub dynamic_register_node : Public {
    my ($class, %postdata )  = @_;
    my @require = qw(mac username);
    my @found = grep {exists $postdata{$_}} @require;
    return unless validate_argv(\@require,  \@found);

    my $logger = pf::log::get_logger();
    my $profile = pf::Portal::ProfileFactory->instantiate($postdata{'mac'});
    my $node_info = pf::node::node_view($postdata{'mac'});
    my @sources = ($profile->getInternalSources, $profile->getExclusiveSources );
    my $stripped_user = '';

    my $params = {
        username => $postdata{'username'},
        connection_type => $node_info->{'last_connection_type'},
        SSID => $node_info->{'last_ssid'},
        stripped_user_name => $stripped_user,
    };

    my $source;
    my $role = &pf::authentication::match([@sources], $params, $Actions::SET_ROLE, \$source);
    #Compute autoreg if we use autoreg
    my $value = &pf::authentication::match([@sources], $params, $Actions::SET_ACCESS_DURATION);
    if (defined $value) {
        $logger->trace("No unregdate found - computing it from access duration");
        $value = pf::config::access_duration($value);
    }
    else {
        $value = &pf::authentication::match([@sources], $params, $Actions::SET_UNREG_DATE);
        $value = pf::config::dynamic_unreg_date($value);
    }
    if (defined $value) {
        my %info = (
            'unregdate' => $value,
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
        pf::node::node_register($postdata{'mac'}, $postdata{'username'}, %info);
        pf::enforcement::reevaluate_access( $postdata{'mac'}, 'manage_register' );
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

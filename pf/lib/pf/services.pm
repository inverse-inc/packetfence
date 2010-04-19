package pf::services;

=head1 NAME

pf::services - module to manage the PacketFence services and daemons.

=head1 DESCRIPTION

pf::services contains the functions necessary to control the different 
PacketFence services and daemons. It also contains the functions used 
to generate or validate some configuration files.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files: F<dhcpd_vlan.conf>, 
F<named-vlan.conf>, F<named-isolation.ca>, F<named-registration.ca>, 
F<networks.conf>, F<violations.conf> and F<switches.conf>.

Generate the following configuration files: F<dhcpd.conf>, F<named.conf>, 
F<snort.conf>, F<httpd.conf>, F<snmptrapd.conf>.

=cut

use strict;
use warnings;
use File::Basename;
use Config::IniFiles;
use Log::Log4perl;
use UNIVERSAL::require;
use IPC::Cmd qw[can_run run];

use pf::config;
use pf::util;
use pf::violation qw(violation_view_open_uniq);
use pf::node qw(nodes_registered_not_violators);
use pf::trigger qw(trigger_delete_all);
use pf::class qw(class_view_all class_merge);
use pf::SwitchFactory;

my %flags;
$flags{'httpd'}          = "-f $conf_dir/httpd.conf";
$flags{'pfdetect'}       = "-d -p $install_dir/var/alert &";
$flags{'pfmon'}          = "-d &";
$flags{'pfdhcplistener'} = "-d &";
$flags{'pfredirect'}     = "-d &";
$flags{'pfsetvlan'}      = "-d &";
$flags{'dhcpd'}
    = " -lf $conf_dir/dhcpd/dhcpd.leases -cf $conf_dir/dhcpd.conf "
    . join( " ", get_dhcp_devs() );
$flags{'named'} = "-u pf -c $install_dir/conf/named.conf";
$flags{'snmptrapd'}
    = "-n -c $conf_dir/snmptrapd.conf -C -A -Lf $install_dir/logs/snmptrapd.log -p $install_dir/var/snmptrapd.pid -On";

if ( isenabled( $Config{'trapping'}{'detection'} ) && $monitor_int ) {
    $flags{'snort'}
        = "-u pf -c $conf_dir/snort.conf -i "
        . $monitor_int
        . " -N -D -l $install_dir/var";
}

=head1 SUBROUTINES

=over

=item * service_ctl

=cut

sub service_ctl {
    my ( $daemon, $action, $quick ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::services');
    my $service
        = ( $Config{'services'}{$daemon} || "$install_dir/sbin/$daemon" );
    my $exe = basename($service);
    $logger->info("$service $action");
    if ( $exe
        =~ /^(named|dhcpd|pfdhcplistener|pfmon|pfdetect|pfredirect|snort|httpd|snmptrapd|pfsetvlan)$/
        )
    {
        $exe = $1;
    CASE: {
            $action eq "start" && do {
                return (0)
                    if (
                    $exe =~ /dhcpd/
                    && (( $Config{'network'}{'mode'} =~ /^arp$/ )
                        || (   ( $Config{'network'}{'mode'} =~ /^vlan$/i )
                            && ( !isenabled( $Config{'vlan'}{'dhcpd'} ) ) )
                    )
                    );
                return (0)
                    if ( $exe =~ /snort/
                    && !isenabled( $Config{'trapping'}{'detection'} ) );
                return (0)
                    if ( $exe =~ /pfdhcplistener/
                    && !isenabled( $Config{'network'}{'dhcpdetector'} ) );
                return (0)
                    if ( $exe =~ /snmptrapd/
                    && !( $Config{'network'}{'mode'} =~ /vlan/i ) );
                return (0)
                    if ( $exe =~ /pfsetvlan/
                    && !( $Config{'network'}{'mode'} =~ /vlan/i ) );
                return (0)
                    if (
                    $exe =~ /named/
                    && !(
                           ( $Config{'network'}{'mode'} =~ /vlan/i )
                        && ( isenabled( $Config{'vlan'}{'named'} ) )
                    )
                    );
                if ( $daemon =~ /(named|dhcpd|snort|httpd|snmptrapd)/
                    && !$quick )
                {
                    my $confname = "generate_" . $daemon . "_conf";
                    $logger->info(
                        "Generating configuration file for $exe ($confname)");
                    my %serviceHash = (
                        'named' => \&generate_named_conf,
                        'dhcpd' => \&generate_dhcpd_conf,
                        'snort' => \&generate_snort_conf,
                        'httpd' => \&generate_httpd_conf,
                        'snmptrapd' => \&generate_snmptrapd_conf
                    );
                    if ( $serviceHash{$daemon} ) {
                        $serviceHash{$daemon}->();
                    } else {
                        print "No such sub: $confname\n";
                    }
                }
                if (  ( $service =~ /named|dhcpd|pfdhcplistener|pfmon|pfdetect|pfredirect|snort|httpd|snmptrapd|pfsetvlan/ )
                      && ( $daemon =~ /named|dhcpd|pfdhcplistener|pfmon|pfdetect|pfredirect|snort|httpd|snmptrapd|pfsetvlan/ )
                      && ( defined( $flags{$daemon} ) ) ) {
                    if ( $daemon ne 'pfdhcplistener' ) {
                        if ( $daemon eq 'dhcpd' ) {
                            manage_Static_Route(1);
                        }
                        if (   ( $daemon eq 'pfsetvlan' )
                            && ( !switches_conf_is_valid() ) )
                        {
                            $logger->error_warn("Errors in switches.conf. This can be problematic for "
                                . "pfsetvlan's operation. Check logs for details.");
                        }
                        $logger->info(
                            "Starting $exe with '$service $flags{$daemon}'");
                        my $cmd_line = "$service $flags{$daemon}";
                        if ($cmd_line =~ /(.+)/) {
                            $cmd_line = $1;
                            return ( system($cmd_line) );
                        }
                    } else {
                        if ( isenabled( $Config{'network'}{'dhcpdetector'} ) )
                        {
                            my @devices = @listen_ints;
                            push @devices, @dhcplistener_ints;
                            @devices = get_dhcp_devs()
                                if (
                                $Config{'network'}{'mode'} =~ /^dhcp$/i );
                            foreach my $dev (@devices) {
                                my $cmd_line = "$service -i $dev $flags{$daemon}";
                                if ($cmd_line =~ /^(.+)$/) {
                                    $cmd_line = $1;
                                    $logger->info(
                                        "Starting $exe with '$cmd_line'"
                                    );
                                    system($cmd_line);
                                }
                            }
                            return 1;
                        }
                    }
                }
                last CASE;
            };
            $action eq "stop" && do {
                #my @debug= system('pkill','-f',$exe);
                $logger->info("Stopping $exe with 'pkill $exe'");
                eval { `pkill $exe`; };
                if ($@) {
                    $logger->logcroak("Can't stop $exe with 'pkill $exe': $@");
                    return;
                }

                if ( $service =~ /(dhcpd)/) {
                    manage_Static_Route();
                }

                #$logger->info("pkill shows " . join(@debug));
                my $maxWait = 10;
                my $curWait = 0;
                while (( $curWait < $maxWait )
                    && ( service_ctl( $exe, "status" ) ne "0" ) )
                {
                    $logger->info("Waiting for $exe to stop");
                    sleep(2);
                    $curWait++;
                }
                if ( -e $install_dir . "/var/$exe.pid" ) {
                    $logger->info("Removing $install_dir/var/$exe.pid");
                    unlink( $install_dir . "/var/$exe.pid" );
                }
                last CASE;
            };
            $action eq "restart" && do {
                service_ctl( "pfdetect", "stop" ) if ( $daemon eq "snort" );
                service_ctl( $daemon, "stop" );

                service_ctl( "pfdetect", "start" ) if ( $daemon eq "snort" );
                service_ctl( $daemon, "start" );
                last CASE;
            };
            $action eq "status" && do {
                my $pid;
                chop( $pid = `pidof -x $exe` );
                $pid = 0 if ( !$pid );
                $logger->info("pidof -x $exe returned $pid");
                return ($pid);
            }
        }
    } else {
        $logger->logcroak("unknown service $exe!");
        return 0;
    }
    return 1;
}

=item * service_list

return an array of enabled services

=cut

sub service_list {
    my @services         = @_;
    my @finalServiceList = ();
    my $snortflag        = 0;
    foreach my $service (@services) {
        if ( $service eq "snort" ) {
            $snortflag = 1
                if ( isenabled( $Config{'trapping'}{'detection'} ) );
        } elsif ( $service eq "pfdetect" ) {
            push @finalServiceList, $service
                if ( isenabled( $Config{'trapping'}{'detection'} ) );
        } elsif ( $service eq "pfredirect" ) {
            push @finalServiceList, $service
                if ( $Config{'ports'}{'listeners'} );
        } elsif ( $service eq "dhcpd" ) {
            push @finalServiceList, $service
                if (
                ( $Config{'network'}{'mode'} =~ /^dhcp$/i )
                || (   ( $Config{'network'}{'mode'} =~ /^vlan$/i )
                    && ( isenabled( $Config{'vlan'}{'dhcpd'} ) ) )
                );
        } elsif ( $service eq "snmptrapd" ) {
            push @finalServiceList, $service
                if ( $Config{'network'}{'mode'} =~ /vlan/i );
        } elsif ( $service eq "named" ) {
            push @finalServiceList, $service
                if ( ( $Config{'network'}{'mode'} =~ /vlan/i )
                && ( isenabled( $Config{'vlan'}{'named'} ) ) );
        } elsif ( $service eq "pfsetvlan" ) {
            push @finalServiceList, $service
                if ( $Config{'network'}{'mode'} =~ /vlan/i );
        } else {
            push @finalServiceList, $service;
        }
    }

    #add snort last
    push @finalServiceList, "snort" if ($snortflag);
    return @finalServiceList;
}

=item * generate_named_conf

=cut

sub generate_named_conf {
    my $logger = Log::Log4perl::get_logger('pf::services');
    require Net::Netmask;
    import Net::Netmask;
    my %tags;
    $tags{'template'}    = "$conf_dir/templates/named_vlan.conf";
    $tags{'install_dir'} = $install_dir;

    my %network_conf;
    tie %network_conf, 'Config::IniFiles',
        ( -file => "$conf_dir/networks.conf", -allowempty => 1 );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error(
            "Error reading networks.conf: " . join( "\n", @errors ) . "\n" );
        return 0;
    }

    my @routed_isolation_nets_named;
    my @routed_registration_nets_named;
    foreach my $section ( tied(%network_conf)->Sections ) {
        foreach my $key ( keys %{ $network_conf{$section} } ) {
            $network_conf{$section}{$key} =~ s/\s+$//;
        }
        if ( ( $network_conf{$section}{'named'} eq 'enabled' ) 
          && ( exists( $network_conf{$section}{'type'} ) ) ) {
            if ( lc($network_conf{$section}{'type'}) eq 'isolation' ) {
                my $isolation_obj = new Net::Netmask( $section,
                    $network_conf{$section}{'netmask'} );
                push @routed_isolation_nets_named, $isolation_obj;
            } elsif ( lc($network_conf{$section}{'type'}) eq 'registration' ) {
                my $registration_obj = new Net::Netmask( $section,
                    $network_conf{$section}{'netmask'} );
                push @routed_registration_nets_named, $registration_obj;
            }
        }
    }

    $tags{'registration_clients'} = "";
    foreach my $net ( @routed_registration_nets_named ) {
        $tags{'registration_clients'} .= $net . "; ";
    }
    $tags{'isolation_clients'} = "";
    foreach my $net ( @routed_isolation_nets_named ) {
        $tags{'isolation_clients'} .= $net . "; ";
    }
    parse_template(
        \%tags,
        "$conf_dir/templates/named_vlan.conf",
        "$install_dir/conf/named.conf"
    );

    my %tags_isolation;
    $tags_isolation{'template'} = "$conf_dir/templates/named-isolation.ca";
    $tags_isolation{'hostname'} = $Config{'general'}{'hostname'};
    $tags_isolation{'incharge'}
        = "pf."
        . $Config{'general'}{'hostname'} . "."
        . $Config{'general'}{'domain'};
    parse_template(
        \%tags_isolation,
        "$conf_dir/templates/named-isolation.ca",
        "$install_dir/conf/named/named-isolation.ca"
    );

    my %tags_registration;
    $tags_registration{'template'}
        = "$conf_dir/templates/named-registration.ca";
    $tags_registration{'hostname'} = $Config{'general'}{'hostname'};
    $tags_registration{'incharge'}
        = "pf."
        . $Config{'general'}{'hostname'} . "."
        . $Config{'general'}{'domain'};
    parse_template(
        \%tags_registration,
        "$conf_dir/templates/named-registration.ca",
        "$install_dir/conf/named/named-registration.ca"
    );

    return 1;
}

# Adding or removing static routes for Registration and Isolation VLANs
sub manage_Static_Route {
    my $add_Route = @_;
    my $logger = Log::Log4perl::get_logger('pf::services');
    my %tags;
    $tags{'template'}    = "$conf_dir/templates/named_vlan.conf";
    $tags{'install_dir'} = $install_dir;

    my %network_conf;
    tie %network_conf, 'Config::IniFiles', ( -file => "$conf_dir/networks.conf", -allowempty => 1 );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error("Error reading networks.conf: " . join( "\n", @errors ) . "\n" );
        return 0;
    }

    foreach my $section ( tied(%network_conf)->Sections ) {
        foreach my $key ( keys %{ $network_conf{$section} } ) {
            $network_conf{$section}{$key} =~ s/\s+$//;
        }

        if ( ($network_conf{$section}{'dhcpd'} eq 'enabled') && (exists($network_conf{$section}{'type'})) && ($network_conf{$section}{'pf_gateway'} =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) ) {
            if ( ( lc($network_conf{$section}{'type'}) eq 'isolation' ) || ( lc($network_conf{$section}{'type'}) eq 'registration' ) ) {
                my $add_del = $add_Route ? 'add' : 'del';
                my $full_path = can_run('route') or $logger->error("route is not installed! Can not add static routes to routed Registration and Isolation VLANs");
                my $cmd = "$full_path $add_del -net $section netmask " . $network_conf{$section}{'netmask'} . " gw " . $network_conf{$section}{'pf_gateway'};
                my( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 0 );
                if( $success ) {
                    $logger->info("Command `$cmd` succedeed !");
                } else {
                    $logger->error("Command `$cmd` failed !");
                }
            }
        }
    }
}

=item * generate_dhcpd_vlan_conf

=cut

sub generate_dhcpd_vlan_conf {
    my $logger = Log::Log4perl::get_logger('pf::services');
    my %tags;
    $tags{'template'} = "$conf_dir/templates/dhcpd_vlan.conf";
    $tags{'networks'} = '';

    my %network_conf;
    tie %network_conf, 'Config::IniFiles',
        ( -file => "$conf_dir/networks.conf", -allowempty => 1 );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error(
            "Error reading networks.conf: " . join( "\n", @errors ) . "\n" );
        return 0;
    }
    foreach my $section ( tied(%network_conf)->Sections ) {
        foreach my $key ( keys %{ $network_conf{$section} } ) {
            $network_conf{$section}{$key} =~ s/\s+$//;
        }
        if ( $network_conf{$section}{'dhcpd'} eq 'enabled' ) {
            $tags{'networks'} .= <<"EOT";
subnet $section netmask $network_conf{$section}{'netmask'} {
  option routers $network_conf{$section}{'gateway'};
  option subnet-mask $network_conf{$section}{'netmask'};
  option domain-name "$network_conf{$section}{'domain-name'}";
  option domain-name-servers $network_conf{$section}{'dns'};
  range $network_conf{$section}{'dhcp_start'} $network_conf{$section}{'dhcp_end'};
  default-lease-time $network_conf{$section}{'dhcp_default_lease_time'};
  max-lease-time $network_conf{$section}{'dhcp_max_lease_time'};
}

EOT
        }
    }

    parse_template( \%tags, "$conf_dir/templates/dhcpd_vlan.conf",
        "$conf_dir/dhcpd.conf" );

    return 1;
}

=item * generate_dhcpd_conf

=cut

sub generate_dhcpd_conf {
    if ( $Config{'network'}{'mode'} =~ /vlan/i ) {
        generate_dhcpd_vlan_conf();
        return;
    }
    my %tags;
    my $logger = Log::Log4perl::get_logger('pf::services');
    $tags{'template'}   = "$conf_dir/templates/dhcpd.conf";
    $tags{'domain'}     = $Config{'general'}{'domain'};
    $tags{'hostname'}   = $Config{'general'}{'hostname'};
    $tags{'dnsservers'} = $Config{'general'}{'dnsservers'};

    parse_template( \%tags, "$conf_dir/templates/dhcpd.conf",
        "$conf_dir/dhcpd.conf" );

    my %shared_nets;
    $logger->info("generating $conf_dir/dhcpd.conf");
    foreach my $dhcp ( tied(%Config)->GroupMembers("dhcp") ) {
        my @registered_scopes;
        my @unregistered_scopes;
        my @isolation_scopes;

        if ( defined( $Config{$dhcp}{'registered_scopes'} ) ) {
            @registered_scopes
                = split( /\s*,\s*/, $Config{$dhcp}{'registered_scopes'} );
        }
        if ( defined( $Config{$dhcp}{'unregistered_scopes'} ) ) {
            @unregistered_scopes
                = split( /\s+/, $Config{$dhcp}{'unregistered_scopes'} );
        }
        if ( defined( $Config{$dhcp}{'isolation_scopes'} ) ) {
            @isolation_scopes
                = split( /\s+/, $Config{$dhcp}{'isolation_scopes'} );
        }

        foreach my $registered_scope (@registered_scopes) {
            my $reg_obj = new Net::Netmask(
                $Config{ 'scope ' . $registered_scope }{'network'} );
            $reg_obj->tag( "scope", $registered_scope );
            foreach my $shared_net ( keys(%shared_nets) ) {
                if ( $shared_net ne $dhcp
                    && defined(
                        $shared_nets{$shared_net}{ $reg_obj->desc() } ) )
                {
                    $logger->logcroak( "Network "
                            . $reg_obj->desc()
                            . " is defined in another shared-network!\n" );
                }
            }
            push(
                @{ $shared_nets{$dhcp}{ $reg_obj->desc() }{'registered'} },
                $reg_obj
            );
        }
        foreach my $isolation_scope (@isolation_scopes) {
            my $iso_obj = new Net::Netmask(
                $Config{ 'scope ' . $isolation_scope }{'network'} );
            $iso_obj->tag( "scope", $isolation_scope );
            foreach my $shared_net ( keys(%shared_nets) ) {
                if ( $shared_net ne $dhcp
                    && defined(
                        $shared_nets{$shared_net}{ $iso_obj->desc() } ) )
                {
                    $logger->logcroak( "Network "
                            . $iso_obj->desc()
                            . " is defined in another shared-network!\n" );
                }
            }
            push(
                @{ $shared_nets{$dhcp}{ $iso_obj->desc() }{'isolation'} },
                $iso_obj
            );
        }
        foreach my $unregistered_scope (@unregistered_scopes) {
            my $unreg_obj = new Net::Netmask(
                $Config{ 'scope ' . $unregistered_scope }{'network'} );
            $unreg_obj->tag( "scope", $unregistered_scope );
            foreach my $shared_net ( keys(%shared_nets) ) {
                if ($shared_net ne $dhcp
                    && defined(
                        $shared_nets{$shared_net}{ $unreg_obj->desc() }
                    )
                    )
                {
                    $logger->logcroak( "Network "
                            . $unreg_obj->desc()
                            . " is defined in another shared-network!\n" );
                }
            }
            push(
                @{  $shared_nets{$dhcp}{ $unreg_obj->desc() }{'unregistered'}
                    },
                $unreg_obj
            );
        }
    }

    #open dhcpd.conf file
    my $dhcpdconf_fh;
    open( $dhcpdconf_fh, '>>', "$conf_dir/dhcpd.conf" )
        || $logger->logcroak("Unable to append to $conf_dir/dhcpd.conf: $!");
    foreach my $internal_interface ( get_internal_devs_phy() ) {
        my $dhcp_interface = get_internal_info($internal_interface);
        print {$dhcpdconf_fh} "subnet "
            . $dhcp_interface->base()
            . " netmask "
            . $dhcp_interface->mask()
            . " {\n  not authoritative;\n}\n";
    }
    foreach my $shared_net ( keys(%shared_nets) ) {
        my $printable_shared = $shared_net;
        $printable_shared =~ s/dhcp //;
        print {$dhcpdconf_fh} "shared-network $printable_shared {\n";
        foreach my $key ( keys( %{ $shared_nets{$shared_net} } ) ) {
            my $tmp_obj = new Net::Netmask($key);
            print {$dhcpdconf_fh} "  subnet "
                . $tmp_obj->base()
                . " netmask "
                . $tmp_obj->mask() . " {\n";

            if (defined( @{ $shared_nets{$shared_net}{$key}{'registered'} } )
                )
            {
                foreach my $reg (
                    @{ $shared_nets{$shared_net}{$key}{'registered'} } )
                {

                    my $range = normalize_dhcpd_range(
                        $Config{ 'scope ' . $reg->tag("scope") }{'range'} );
                    if ( !$range ) {
                        $logger->logcroak( "Invalid scope range: "
                                . $Config{ 'scope ' . $reg->tag("scope") }
                                {'range'} );
                    }
                    print {$dhcpdconf_fh} "    pool {\n";
                    print {$dhcpdconf_fh} "      # I AM A REGISTERED SCOPE\n";
                    print {$dhcpdconf_fh} "      deny unknown clients;\n";
                    print {$dhcpdconf_fh}
                        "      allow members of \"registered\";\n";
                    print {$dhcpdconf_fh} "      option routers "
                        . $Config{ 'scope ' . $reg->tag("scope") }{'gateway'}
                        . ";\n";

                    my $lease_time;
                    if ( defined( $Config{$shared_net}{'registered_lease'} ) )
                    {
                        $lease_time
                            = $Config{$shared_net}{'registered_lease'};
                    } else {
                        $lease_time = 7200;
                    }

                    print {$dhcpdconf_fh}
                        "      max-lease-time $lease_time;\n";
                    print {$dhcpdconf_fh}
                        "      default-lease-time $lease_time;\n";
                    print {$dhcpdconf_fh} "      range $range;\n";
                    print {$dhcpdconf_fh} "    }\n";
                }
            }

            if (defined( @{ $shared_nets{$shared_net}{$key}{'isolation'} } ) )
            {
                foreach my $iso (
                    @{ $shared_nets{$shared_net}{$key}{'isolation'} } )
                {

                    my $range = normalize_dhcpd_range(
                        $Config{ 'scope ' . $iso->tag("scope") }{'range'} );
                    if ( !$range ) {
                        $logger->logcroak( "Invalid scope range: "
                                . $Config{ 'scope ' . $iso->tag("scope") }
                                {'range'} );
                    }

                    print {$dhcpdconf_fh} "    pool {\n";
                    print {$dhcpdconf_fh} "      # I AM AN ISOLATION SCOPE\n";
                    print {$dhcpdconf_fh} "      deny unknown clients;\n";
                    print {$dhcpdconf_fh}
                        "      allow members of \"isolated\";\n";
                    print {$dhcpdconf_fh} "      option routers "
                        . $Config{ 'scope ' . $iso->tag("scope") }{'gateway'}
                        . ";\n";

                    my $lease_time;
                    if ( defined( $Config{$shared_net}{'isolation_lease'} ) )
                    {
                        $lease_time = $Config{$shared_net}{'isolation_lease'};
                    } else {
                        $lease_time = 120;
                    }

                    print {$dhcpdconf_fh}
                        "      max-lease-time $lease_time;\n";
                    print {$dhcpdconf_fh}
                        "      default-lease-time $lease_time;\n";
                    print {$dhcpdconf_fh} "      range $range;\n";
                    print {$dhcpdconf_fh} "    }\n";
                }
            }

            if (defined(
                    @{ $shared_nets{$shared_net}{$key}{'unregistered'} }
                )
                )
            {
                foreach my $unreg (
                    @{ $shared_nets{$shared_net}{$key}{'unregistered'} } )
                {

                    my $range = normalize_dhcpd_range(
                        $Config{ 'scope ' . $unreg->tag("scope") }{'range'} );
                    if ( !$range ) {
                        $logger->logcroak( "Invalid scope range: "
                                . $Config{ 'scope ' . $unreg->tag("scope") }
                                {'range'} );
                    }

                    print {$dhcpdconf_fh} "    pool {\n";
                    print {$dhcpdconf_fh}
                        "      # I AM AN UNREGISTERED SCOPE\n";
                    print {$dhcpdconf_fh} "      allow unknown clients;\n";
                    print {$dhcpdconf_fh} "      option routers "
                        . $Config{ 'scope ' . $unreg->tag("scope") }
                        {'gateway'} . ";\n";

                    my $lease_time;
                    if (defined( $Config{$shared_net}{'unregistered_lease'} )
                        )
                    {
                        $lease_time
                            = $Config{$shared_net}{'unregistered_lease'};
                    } else {
                        $lease_time = 120;
                    }

                    print {$dhcpdconf_fh}
                        "      max-lease-time $lease_time;\n";
                    print {$dhcpdconf_fh}
                        "      default-lease-time $lease_time;\n";
                    print {$dhcpdconf_fh} "      range $range;\n";
                    print {$dhcpdconf_fh} "    }\n";
                }
            }

            print {$dhcpdconf_fh} "  }\n";
        }
        print {$dhcpdconf_fh} "}\n";
    }
    print {$dhcpdconf_fh} "include \"$conf_dir/isolated.mac\";\n";
    print {$dhcpdconf_fh} "include \"$conf_dir/registered.mac\";\n";
    close $dhcpdconf_fh;

    #close(DHCPDCONF);

    generate_dhcpd_iso();
    generate_dhcpd_reg();

    return 1;
}

=item * generate_dhcpd_iso

open isolated.mac file

=cut

sub generate_dhcpd_iso {
    my $logger = Log::Log4perl::get_logger('pf::services');
    my $isomac_fh;
    open( $isomac_fh, '>', "$conf_dir/isolated.mac" )
        || $logger->logcroak("Unable to open $conf_dir/isolated.mac : $!");
    my @isolated = violation_view_open_uniq();
    my @isolatednodes;
    foreach my $row (@isolated) {
        my $mac      = $row->{'mac'};
        my $hostname = $mac;
        $hostname =~ s/://g;
        print {$isomac_fh}
            "host $hostname { hardware ethernet $mac; } subclass \"isolated\" 01:$mac;";
    }

    close( $isomac_fh );
    return 1;
}

=item * generate_dhcpd_reg

open registered.mac file

=cut

sub generate_dhcpd_reg {
    my $logger = Log::Log4perl::get_logger('pf::services');
    if ( isenabled( $Config{'trapping'}{'registration'} ) ) {
        my $regmac_fh;
        open( $regmac_fh, '>', "$conf_dir/registered.mac" )
            || $logger->logcroak(
            "Unable to open $conf_dir/registered.mac : $!");
        my @registered = nodes_registered_not_violators();
        my @registerednodes;
        foreach my $row (@registered) {
            my $mac      = $row->{'mac'};
            my $hostname = $mac;
            $hostname =~ s/://g;
            print {$regmac_fh}
                "host $hostname { hardware ethernet $mac; } subclass \"registered\" 01:$mac;";
        }

        close( $regmac_fh );
    }
    return 1;
}

=item * generate_snort_conf

=cut

sub generate_snort_conf {
    my $logger = Log::Log4perl::get_logger('pf::services');
    my %tags;
    $tags{'template'}      = "$conf_dir/templates/snort.conf";
    $tags{'internal-ips'}  = join( ",", get_internal_ips() );
    $tags{'internal-nets'} = join( ",", get_internal_nets() );
    $tags{'gateways'}      = join( ",", get_gateways() );
    $tags{'dhcp_servers'}  = $Config{'general'}{'dhcpservers'};
    $tags{'dns_servers'}   = $Config{'general'}{'dnsservers'};
    $tags{'install_dir'}   = $install_dir;
    my %violations_conf;
    tie %violations_conf, 'Config::IniFiles',
        ( -file => "$conf_dir/violations.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error( "Error reading violations.conf: " 
                        .  join( "\n", @errors ) . "\n" );
        return 0;
    }

    my @rules;

    foreach my $rule (
        split( /\s*,\s*/, $violations_conf{'defaults'}{'snort_rules'} ) )
    {

        #append install_dir if the path doesn't start with /
        $rule = "\$RULE_PATH/$rule" if ( $rule !~ /^\// );
        push @rules, "include $rule";
    }
    $tags{'snort_rules'} = join( "\n", @rules );
    $logger->info("generating $conf_dir/snort.conf");
    parse_template( \%tags, "$conf_dir/templates/snort.conf",
        "$conf_dir/snort.conf" );
    return 1;
}

=item * generate_snmptrapd_conf

=cut

sub generate_snmptrapd_conf {
    my $logger = Log::Log4perl::get_logger('pf::services');
    my %tags;
    $tags{'authLines'} = '';
    $tags{'userLines'} = '';
    my %SNMPv3Users;
    my %SNMPCommunities;
    my $switchFactory
        = new pf::SwitchFactory( -configFile => "$conf_dir/switches.conf" );
    my %switchConfig = %{ $switchFactory->{_config} };

    foreach my $key ( sort keys %switchConfig ) {
        if ( $key ne 'default' ) {
            if (ref($switchConfig{$key}{'type'}) eq 'ARRAY') {
                $logger->warn("There is an error in your $conf_dir/switches.conf. "
                    . "I will skip $key from snmptrapd config");
                next;
            }
            my $switch = $switchFactory->instantiate($key);
            if (!$switch) {
                $logger->error("Can not instantiate switch $key!");
            } else {
                if ( $switch->{_SNMPVersionTrap} eq '3' ) {
                    $SNMPv3Users{ $switch->{_SNMPUserNameTrap} }
                        = '-e ' . $switch->{_SNMPEngineID} . ' '
                        . $switch->{_SNMPUserNameTrap} . ' '
                        . $switch->{_SNMPAuthProtocolTrap} . ' '
                        . $switch->{_SNMPAuthPasswordTrap} . ' '
                        . $switch->{_SNMPPrivProtocolTrap} . ' '
                        . $switch->{_SNMPPrivPasswordTrap};
                } else {
                    $SNMPCommunities{ $switch->{_SNMPCommunityTrap} } = 1;
                }
            }
        }
    }
    foreach my $userName ( sort keys %SNMPv3Users ) {
        $tags{'userLines'}
            .= "createUser " . $SNMPv3Users{$userName} . "\n";
        $tags{'authLines'} .= "authUser log $userName priv\n";
    }
    foreach my $community ( sort keys %SNMPCommunities ) {
        $tags{'authLines'} .= "authCommunity log $community\n";
    }
    $tags{'template'} = "$conf_dir/templates/snmptrapd.conf";
    $logger->info("generating $conf_dir/snmptrapd.conf");
    parse_template( \%tags, "$conf_dir/templates/snmptrapd.conf",
        "$conf_dir/snmptrapd.conf" );
    return 1;
}

=item * generate_httpd_conf

=cut

sub generate_httpd_conf {
    my ( %tags, $httpdconf_fh, $authconf_fh );
    my $logger = Log::Log4perl::get_logger('pf::services');
    $tags{'template'}      = "$conf_dir/templates/httpd.conf";
    $tags{'internal-nets'} = join( " ", get_internal_nets() );
    $tags{'routed-nets'}   = join( " ", get_routed_isolation_nets() ) . " "
        . join( " ", get_routed_registration_nets() );
    $tags{'hostname'}    = $Config{'general'}{'hostname'};
    $tags{'domain'}      = $Config{'general'}{'domain'};
    $tags{'admin_port'}  = $Config{'ports'}{'admin'};
    $tags{'install_dir'} = $install_dir;

    my @proxies;
    my %proxy_configs = %{ $Config{'proxies'} };
    foreach my $proxy ( keys %proxy_configs ) {
        if ( $proxy =~ /^\// ) {
            if ( $proxy !~ /^\/(content|admin|redirect|cgi-bin)/ ) {
                push @proxies,
                    "ProxyPassReverse $proxy $proxy_configs{$proxy}";
                push @proxies, "ProxyPass $proxy $proxy_configs{$proxy}";
                $logger->warn(
                    "proxy $proxy is not relative - add path to apache rewrite exclude list!"
                );
            } else {
                $logger->warn("proxy $proxy conflicts with PF paths!");
                next;
            }
        } else {
            push @proxies,
                  "ProxyPassReverse /proxies/" 
                . $proxy . " "
                . $proxy_configs{$proxy};
            push @proxies,
                "ProxyPass /proxies/" . $proxy . " " . $proxy_configs{$proxy};
        }
    }
    $tags{'proxies'} = join( "\n", @proxies );

    my @contentproxies;
    if ( $Config{'trapping'}{'passthrough'} eq "proxy" ) {
        my @proxies = class_view_all();
        foreach my $row (@proxies) {
            my $url = $row->{'url'};
            my $vid = $row->{'vid'};
            next if ( ( !defined($url) ) || ( $url =~ /^\// ) );
            if ( $url !~ /^(http|https):\/\// ) {
                $logger->warn(
                    "vid " . $vid . ": unrecognized content URL: " . $url );
                next;
            }
            if ( $url =~ /^((http|https):\/\/.+)\/$/ ) {
                push @contentproxies, "ProxyPass		/content/$vid/ $url";
                push @contentproxies, "ProxyPassReverse	/content/$vid/ $url";
                push @contentproxies, "ProxyHTMLURLMap		$1 /content/$vid";
            } else {
                $url =~ /^((http|https):\/\/.+)\//;
                push @contentproxies, "ProxyPass		/content/$vid/ $1/";
                push @contentproxies, "ProxyPassReverse	/content/$vid/ $1/";
                push @contentproxies, "ProxyHTMLURLMap		$url /content/$vid";
            }
            push @contentproxies, "ProxyPass		/content/$vid $url";
            push @contentproxies, "<Location /content/$vid>";
            push @contentproxies, "  SetOutputFilter	proxy-html";
            push @contentproxies, "  ProxyHTMLDoctype	HTML";
            push @contentproxies, "  ProxyHTMLURLMap	/ /content/$vid/";
            push @contentproxies,
                "  ProxyHTMLURLMap	/content/$vid /content/$vid";
            push @contentproxies, "  RequestHeader	unset	Accept-Encoding";
            push @contentproxies, "</Location>";
        }
    }
    $tags{'content-proxies'} = join( "\n", @contentproxies );

    $logger->info("generating $conf_dir/httpd.conf");
    parse_template( \%tags, "$conf_dir/templates/httpd.conf",
        "$conf_dir/httpd.conf" );
    return 1;
}

=item * switches_conf_is_valid

=cut

sub switches_conf_is_valid {
    my $logger = Log::Log4perl::get_logger('pf::services');
    my %switches_conf;
    tie %switches_conf, 'Config::IniFiles',
        ( -file => "$conf_dir/switches.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error(
            "Error reading switches.conf: " . join( "\n", @errors ) . "\n" );
        return 0;
    }

    # trimming trailing whitespace
    foreach my $section ( tied(%switches_conf)->Sections ) {
        foreach my $key ( keys %{ $switches_conf{$section} } ) {
            $switches_conf{$section}{$key} =~ s/\s+$//;
        }
    }

    my $parsing_successful_flag = 1;
    foreach my $section ( keys %switches_conf ) {
        if ( ( $section ne 'default' )
            && ( $section ne '127.0.0.1' ) ) {

            # validate that switches are not duplicated (we check for type and mode specifically) fixes #766
            if (ref($switches_conf{$section}{'type'}) eq 'ARRAY' || ref($switches_conf{$section}{'mode'}) eq 'ARRAY') {
                $logger->error("There is an error in the switches.conf configuration file around $section. "
                    . "Did you define the same switch twice?");
                $parsing_successful_flag = 0;
                next;
            }

            # check type
            my $type
                = "pf::SNMP::"
                . (    $switches_conf{$section}{'type'}
                    || $switches_conf{'default'}{'type'} );
            if ( ! $type->require() ) {
                $logger->error(
                    "Unknown switch type: $type for switch $section: $@");
                $parsing_successful_flag = 0;
            }

            if ( !valid_ip($section) ) {
                $logger->error("switch IP is invalid for $section");
                $parsing_successful_flag = 0;
            }

            # check SNMP version
            my $SNMPVersion
                = (    $switches_conf{$section}{'SNMPVersion'}
                    || $switches_conf{$section}{'version'}
                    || $switches_conf{'default'}{'SNMPVersion'}
                    || $switches_conf{'default'}{'version'} );
            if ( !( $SNMPVersion =~ /^1|2c|3$/ ) ) {
                $logger->error("switch SNMP version is invalid for $section");
                $parsing_successful_flag = 0;
            }
            my $SNMPVersionTrap
                = (    $switches_conf{$section}{'SNMPVersionTrap'}
                    || $switches_conf{'default'}{'SNMPVersionTrap'} );
            if ( !( $SNMPVersionTrap =~ /^1|2c|3$/ ) ) {
                $logger->error(
                    "switch SNMP trap version is invalid for $section");
                $parsing_successful_flag = 0;
            }

            # check uplink
            my $uplink = $switches_conf{$section}{'uplink'}
                || $switches_conf{'default'}{'uplink'};
            if (( !defined($uplink) )
                || (   ( lc($uplink) ne 'dynamic' )
                    && ( !( $uplink =~ /(\d+,)*\d+/ ) ) )
                )
            {
                $logger->error( "switch uplink ("
                        . ( defined($uplink) ? $uplink : 'undefined' )
                        . ") is invalid for $section" );
                $parsing_successful_flag = 0;
            }

            # check mode
            my @valid_switch_modes = (
                'testing', 'ignore', 'production', 'registration',
                'discovery'
            );
            my $mode = $switches_conf{$section}{'mode'}
                || $switches_conf{'default'}{'mode'};
            if ( !grep( { lc($_) eq lc($mode) } @valid_switch_modes ) ) {
                $logger->error("switch mode ($mode) is invalid for $section");
                $parsing_successful_flag = 0;
            }
        }
    }
    if ($parsing_successful_flag == 1) {
        return 1;
    } else {
        return 0;
    }
}

=item * read_violations_conf

=cut

sub read_violations_conf {
    my $logger = Log::Log4perl::get_logger('pf::services');
    my %violations_conf;
    tie %violations_conf, 'Config::IniFiles',
        ( -file => "$conf_dir/violations.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error( "Error reading violations.conf: " 
                        .  join( "\n", @errors ) . "\n" );
        return 0;
    }
    my %violations = class_set_defaults(%violations_conf);

    #clear all triggers at startup
    trigger_delete_all();
    foreach my $violation ( keys %violations ) {

        # parse triggers if they exist
        my @triggers;
        if ( defined $violations{$violation}{'trigger'} ) {
            foreach my $trigger (
                split( /\s*,\s*/, $violations{$violation}{'trigger'} ) )
            {
                my ( $type, $tid ) = split( /::/, $trigger );
                $type = lc($type);
                if ( !grep( { lc($_) eq lc($type) } @valid_trigger_types ) ) {
                    $logger->warn(
                        "invalid trigger '$type' found at $violation");
                    next;
                }
                if ( $tid =~ /(\d+)-(\d+)/ ) {
                    push @triggers, [ $1, $2, $type ];
                } else {
                    push @triggers, [ $tid, $tid, $type ];
                }
            }
        }

        #print Dumper(@triggers);
        class_merge(
            $violation,
            $violations{$violation}{'desc'},
            $violations{$violation}{'auto_enable'},
            $violations{$violation}{'max_enable'},
            $violations{$violation}{'grace'},
            $violations{$violation}{'priority'},
            $violations{$violation}{'url'},
            $violations{$violation}{'max_enable_url'},
            $violations{$violation}{'redirect_url'},
            $violations{$violation}{'button_text'},
            $violations{$violation}{'disable'},
            $violations{$violation}{'vlan'},
            # actions are expected to be in this position (handled in a special way)
            $violations{$violation}{'actions'},
            \@triggers
        );
    }
    return 1;
}

=item * class_set_defaults

=cut

sub class_set_defaults {
    my %violations_conf = @_;
    my %violations      = %violations_conf;

    foreach my $violation ( keys %violations_conf ) {
        foreach my $default ( keys %{ $violations_conf{'defaults'} } ) {
            if ( !defined( $violations{$violation}{$default} ) ) {
                $violations{$violation}{$default}
                    = $violations{'defaults'}{$default};
            }
        }
    }
    delete( $violations{'defaults'} );
    return (%violations);
}

=item * normalize_dhcpd_range

=cut

sub normalize_dhcpd_range {
    my ($range) = @_;
    if ( $range
        =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s*-\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/
        )
    {
        $range =~ s/\s*\-\s*/ /;
        return ($range);
    } elsif (
        $range =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})\s*-\s*(\d{1,3})$/ )
    {
        my $net   = $1;
        my $start = $2;
        my $end   = $3;
        return ("$net.$start $net.$end");
    } elsif ( $range =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
        return ("$range $range");
    } else {
        return;
    }
}

=back

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2009,2010 Inverse inc.

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

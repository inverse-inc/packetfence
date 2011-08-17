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
use Config::IniFiles;
use File::Basename;
use IPC::Cmd qw[can_run run];
use Log::Log4perl;
use Readonly;
use Try::Tiny;
use UNIVERSAL::require;

use pf::config;
use pf::util;
use pf::node qw(nodes_registered_not_violators);
use pf::trigger qw(trigger_delete_all parse_triggers);
use pf::class qw(class_view_all class_merge);
use pf::services::apache;
use pf::services::dhcpd qw(generate_dhcpd_conf);
use pf::services::named qw(generate_named_conf);
use pf::SwitchFactory;

Readonly our @ALL_SERVICES => (
    'named', 'dhcpd', 'snort', 
    'httpd', 'snmptrapd', 
    'pfdetect', 'pfredirect', 'pfsetvlan', 'pfdhcplistener', 'pfmon'
);

my %flags;
$flags{'httpd'}          = "-f $generated_conf_dir/httpd.conf";
$flags{'pfdetect'}       = "-d -p $install_dir/var/alert &";
$flags{'pfmon'}          = "-d &";
$flags{'pfdhcplistener'} = "-d &";
$flags{'pfredirect'}     = "-d &";
$flags{'pfsetvlan'}      = "-d &";
$flags{'dhcpd'} = " -lf $var_dir/dhcpd/dhcpd.leases -cf $generated_conf_dir/dhcpd.conf " . join(" ", @listen_ints);
$flags{'named'} = "-u pf -c $generated_conf_dir/named.conf";
$flags{'snmptrapd'}
    = "-n -c $generated_conf_dir/snmptrapd.conf -C -A -Lf $install_dir/logs/snmptrapd.log -p $install_dir/var/run/snmptrapd.pid -On";

if ( isenabled( $Config{'trapping'}{'detection'} ) && $monitor_int ) {
    $flags{'snort'}
        = "-u pf -c $generated_conf_dir/snort.conf -i "
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
        =~ /^(named|dhcpd|pfdhcplistener|pfmon|pfdetect|pfredirect|snort|httpd|apache2|snmptrapd|pfsetvlan)$/
        )
    {
        $exe = $1;
    CASE: {
            $action eq "start" && do {
                # We won't start dhcpd unless vlan.dhcpd is set to enable
                return (0) if ( $exe =~ /dhcpd/ && !isenabled($Config{'vlan'}{'dhcpd'}) );
                return (0)
                    if ( $exe =~ /snort/
                    && !isenabled( $Config{'trapping'}{'detection'} ) );
                return (0)
                    if ( $exe =~ /pfdhcplistener/
                    && !isenabled( $Config{'network'}{'dhcpdetector'} ) );
                return (0)
                    if ( $exe =~ /snmptrapd/ && !(is_vlan_enforcement_enabled()) );
                return (0)
                    if ( $exe =~ /pfsetvlan/ && !(is_vlan_enforcement_enabled()) );
                return (0)
                    if ($exe =~ /named/ && !( is_vlan_enforcement_enabled() && isenabled($Config{'vlan'}{'named'}) ));
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
                if ( is_inline_enforcement_enabled() 
                || ( is_vlan_enforcement_enabled() && isenabled($Config{'vlan'}{'dhcpd'}) ));
        } elsif ( $service eq "snmptrapd" ) {
            push @finalServiceList, $service if ( is_vlan_enforcement_enabled() );
        } elsif ( $service eq "named" ) {
            push @finalServiceList, $service if (is_vlan_enforcement_enabled() && isenabled($Config{'vlan'}{'named'}));
        } elsif ( $service eq "pfsetvlan" ) {
            push @finalServiceList, $service if ( is_vlan_enforcement_enabled() );
        } else {
            push @finalServiceList, $service;
        }
    }

    #add snort last
    push @finalServiceList, "snort" if ($snortflag);
    return @finalServiceList;
}

# Adding or removing static routes for Registration and Isolation VLANs
sub manage_Static_Route {
    my $add_Route = @_;
    my $logger = Log::Log4perl::get_logger('pf::services');

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};


        if ( defined($net{'next_hop'}) && ($net{'next_hop'} =~ /^(?:\d{1,3}\.){3}\d{1,3}$/) ) {
            my $add_del = $add_Route ? 'add' : 'del';
            my $full_path = can_run('route') 
                or $logger->error("route is not installed! Can't add static routes to routed VLANs.");

            my $cmd = "$full_path $add_del -net $network netmask " . $net{'netmask'} . " gw " . $net{'next_hop'};
            my( $success, $error_code, $full_buf, $stdout_buf, $stderr_buf ) = run( command => $cmd, verbose => 0 );
            if( $success ) {
                $logger->debug("static route successfully added!");
            } else {
                $logger->error("static route injection failed: $cmd");
            }
        }
    }
}

=item * generate_snort_conf

=cut

sub generate_snort_conf {
    my $logger = Log::Log4perl::get_logger('pf::services');
    my %tags;
    $tags{'template'}      = "$conf_dir/snort.conf";
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
    parse_template( \%tags, "$conf_dir/snort.conf",
        "$generated_conf_dir/snort.conf" );
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
    my $switchFactory = pf::SwitchFactory->getInstance();
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
    $tags{'template'} = "$conf_dir/snmptrapd.conf";
    $logger->info("generating $generated_conf_dir/snmptrapd.conf");
    parse_template( \%tags, "$conf_dir/snmptrapd.conf",
        "$generated_conf_dir/snmptrapd.conf" );
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
            my $SNMPVersion = ($switches_conf{$section}{'SNMPVersion'}
                || $switches_conf{$section}{'version'}
                || $switches_conf{'default'}{'SNMPVersion'}
                || $switches_conf{'default'}{'version'}
            );

            if (!defined($SNMPVersion)) {
                $logger->error("Switch SNMP version is missing. Please provide one specific to switch or in default. Config section: $section");
                $parsing_successful_flag = 0;
            } elsif ( !( $SNMPVersion =~ /^1|2c|3$/ ) ) {
                $logger->error("switch SNMP version is invalid for $section");
                $parsing_successful_flag = 0;
            }

            # check SNMP Trap version
            my $SNMPVersionTrap = ($switches_conf{$section}{'SNMPVersionTrap'} || $switches_conf{'default'}{'SNMPVersionTrap'});
            if (!defined($SNMPVersionTrap)) {
                $logger->error("Switch SNMP Trap version is missing. Please provide one specific to switch or in default. Config section: $section");
                $parsing_successful_flag = 0;
            } elsif ( !( $SNMPVersionTrap =~ /^1|2c|3$/ ) ) {
                $logger->error("switch SNMP Trap version is invalid for $section");
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
            my @valid_switch_modes = ( 'testing', 'ignore', 'production', 'registration', 'discovery' );
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
    tie %violations_conf, 'Config::IniFiles', ( -file => "$conf_dir/violations.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error( "Error reading violations.conf: " .  join( "\n", @errors ) . "\n" );
        return 0;
    }
    my %violations = class_set_defaults(%violations_conf);

    #clear all triggers at startup
    trigger_delete_all();
    foreach my $violation ( keys %violations ) {

        # parse triggers if they exist
        my $triggers_ref = [];
        if ( defined $violations{$violation}{'trigger'} ) {
            try {
                $triggers_ref = parse_triggers($violations{$violation}{'trigger'});
            } catch {
                $logger->warn("Violation $violation is ignored: $_");
                $triggers_ref = [];
            };
        }

        # parse grace, try to understand trailing signs, and convert back to seconds 
        if ( defined $violations{$violation}{'grace'} ) {
            # If we can detect s, m, h, d, w or y at the end of the string, we recalculate the number of seconds
            # if we have nothing, we consider it is seconds (s=seconds, m=minutes, h=hours, d=days, w=weeks, y=years)
            $violations{$violation}{'grace'} = normalize_time($violations{$violation}{'grace'});
        }

        # be careful of the way parameters are passed, whitelists, actions and triggers are expected at the end
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
            $violations{$violation}{'whitelisted_categories'},
            $violations{$violation}{'actions'},
            $triggers_ref
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

=back

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2009-2011 Inverse inc.

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

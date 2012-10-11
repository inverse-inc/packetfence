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
use Time::HiRes;
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
use pf::services::radiusd qw(generate_radiusd_conf);
use pf::services::snmptrapd qw(generate_snmptrapd_conf);
use pf::services::snort qw(generate_snort_conf);
use pf::services::suricata qw(generate_suricata_conf);
use pf::SwitchFactory;

Readonly our @ALL_SERVICES => (
    'named', 'dhcpd', 'snort', 'suricata', 'radiusd', 
    'httpd', 'snmptrapd', 
    'pfdetect', 'pfredirect', 'pfsetvlan', 'pfdhcplistener', 'pfmon'
);

my $services = join("|", @ALL_SERVICES);
Readonly our $ALL_BINARIES_RE => qr/$services
    |apache2                                   # httpd on debian
    |freeradius                                # radiusd on debian
$/x;

=head1 Globals

=over

=item service_launchers

sprintf-formatted strings that control how the services should be started. 
    %1$s: is the binary (w/ full path)
    %2$s: optional parameters

=cut
my %service_launchers;
$service_launchers{'httpd'} = "%1\$s -f $generated_conf_dir/httpd.conf";
$service_launchers{'pfdetect'} = "%1\$s -d -p $install_dir/var/alert &";
$service_launchers{'pfmon'} = '%1$s -d &';
$service_launchers{'pfdhcplistener'} = '%1$s -i %2$s -d &';
$service_launchers{'pfredirect'} = '%1$s -d &';
$service_launchers{'pfsetvlan'} = '%1$s -d &';
# TODO the following join on @listen_ints will cause problems with dynamic config reloading
$service_launchers{'dhcpd'} = "%1\$s -lf $var_dir/dhcpd/dhcpd.leases -cf $generated_conf_dir/dhcpd.conf " . join(" ", @listen_ints);
$service_launchers{'named'} = "%1\$s -u pf -c $generated_conf_dir/named.conf";
$service_launchers{'snmptrapd'} = "%1\$s -n -c $generated_conf_dir/snmptrapd.conf -C -A -Lf $install_dir/logs/snmptrapd.log -p $install_dir/var/run/snmptrapd.pid -On";
$service_launchers{'radiusd'} = "%1\$s -d $install_dir/raddb/";

# TODO $monitor_int will cause problems with dynamic config reloading
if ( isenabled( $Config{'trapping'}{'detection'} ) && $monitor_int && $Config{'trapping'}{'detection_engine'} eq 'snort' ) {
    $service_launchers{'snort'} =
        "%1\$s -u pf -c $generated_conf_dir/snort.conf -i $monitor_int " .
        "-N -D -l $install_dir/var --pid-path $install_dir/var/run";
} elsif ( isenabled( $Config{'trapping'}{'detection'} ) && $monitor_int && $Config{'trapping'}{'detection_engine'} eq 'suricata' ) {
    $service_launchers{'suricata'} =
        "%1\$s -D -c $install_dir/var/conf/suricata.yaml -i $monitor_int " . 
        "-l $install_dir/var --pidfile $install_dir/var/run/suricata.pid";
}
=back

=head1 SUBROUTINES

=over

=item * service_ctl

=cut

#FIXME this is ridiculously complex and unfocused for such a simple task.. what is all that duplication?
sub service_ctl {
    my ( $daemon, $action, $quick ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::services');
    my $service = ( $Config{'services'}{"${daemon}_binary"} || "$install_dir/sbin/$daemon" );
    my $binary = basename($service);
    $logger->info("$service $action");
    if ( $binary =~ /^($ALL_BINARIES_RE)$/ ) {
        $binary = $1;
    CASE: {
            $action eq "start" && do {

                # if we shouldn't be running that daemon based on current configuration, skip it
                if (!scalar grep({ $daemon eq $_ } service_list(@ALL_SERVICES))) {
                    $logger->info("$daemon ($service) not started because it's not required based on configuration");
                    return $FALSE;
                }

                if ( $daemon =~ /(named|dhcpd|snort|suricata|httpd|snmptrapd|radiusd)/ && !$quick )
                {
                    my $confname = "generate_" . $daemon . "_conf";
                    $logger->info(
                        "Generating configuration file for $binary ($confname)");
                    my %serviceHash = (
                        'named' => \&generate_named_conf,
                        'dhcpd' => \&generate_dhcpd_conf,
                        'snort' => \&generate_snort_conf,
                        'suricata' => \&generate_suricata_conf,
                        'httpd' => \&generate_httpd_conf,
                        'radiusd' => \&generate_radiusd_conf,
                        'snmptrapd' => \&generate_snmptrapd_conf
                    );
                    if ( $serviceHash{$daemon} ) {
                        $serviceHash{$daemon}->();
                    } else {
                        print "No such sub: $confname\n";
                    }
                }

                # valid daemon and flags are set
                if (grep({ $daemon eq $_ } @ALL_SERVICES) && defined($service_launchers{$daemon})) {

                    if ( $daemon ne 'pfdhcplistener' ) {
                        if ( $daemon eq 'dhcpd' ) {

                            # create var/dhcpd/dhcpd.leases if it doesn't exist
                            pf_run("touch $var_dir/dhcpd/dhcpd.leases") if (!-f $var_dir . '/dhcpd/dhcpd.leases');

                            manage_Static_Route(1);

                        } elsif ( $daemon eq 'radiusd' ) {
                            # TODO: push all these per-daemon initialization into pf::services::...
                            require pf::freeradius;
                            pf::freeradius::freeradius_populate_nas_config();

                        }
                        my $cmd_line = sprintf($service_launchers{$daemon}, $service);
                        $logger->info("Starting $daemon with '$cmd_line'");
                        # FIXME lame taint-mode bypass
                        if ($cmd_line =~ /^(.+)$/) {
                            $cmd_line = $1;
                            my $t0 = Time::HiRes::time();
                            my $return_value = system($cmd_line);
                            my $elapsed = Time::HiRes::time() - $t0;
                            $logger->info(sprintf("Daemon $daemon took %.3f seconds to start.", $elapsed));
                            return $return_value;
                        }
                    } else {
                        if ( isenabled( $Config{'network'}{'dhcpdetector'} ) ) {
                            # putting interfaces to run listener on in hash so that
                            # only one listener per interface will ever run
                            my %interfaces = map { $_ => $TRUE } @listen_ints, @dhcplistener_ints;
                            foreach my $dev (keys %interfaces) {
                                my $cmd_line = sprintf($service_launchers{$daemon}, $service, $dev);
                                # FIXME lame taint-mode bypass
                                if ($cmd_line =~ /^(.+)$/) {
                                    $cmd_line = $1;
                                    $logger->info( "Starting $daemon with '$cmd_line'" );
                                    my $t0 = Time::HiRes::time();
                                    system($cmd_line);
                                    my $elapsed = Time::HiRes::time() - $t0;
                                    $logger->info(sprintf("Daemon $daemon took %.3f seconds to start.", $elapsed));
                                }
                            }
                            return 1;
                        }
                    }
                }
                last CASE;
            };
            $action eq "stop" && do {
                my $cmd = "/usr/bin/pkill $binary";
                $logger->info("Stopping $daemon with '$cmd'");
                eval { `$cmd`; };
                if ($@) {
                    $logger->logcroak("Can't stop $daemon with '$cmd': $@");
                    return;
                }

                if ( $service =~ /(dhcpd)/) {
                    manage_Static_Route();
                }

                my $maxWait = 10;
                my $curWait = 0;
                while (( $curWait < $maxWait )
                    && ( service_ctl( $daemon, "status" ) ne "0" ) )
                {
                    $logger->info("Waiting for $binary to stop");
                    sleep(2);
                    $curWait++;
                }
                if ( -e $install_dir . "/var/$binary.pid" ) {
                    $logger->info("Removing $install_dir/var/$binary.pid");
                    unlink( $install_dir . "/var/$binary.pid" );
                }
                last CASE;
            };
            $action eq "restart" && do {
                service_ctl( "pfdetect", "stop" ) if ( $daemon eq "snort" || $daemon eq "suricata" );
                service_ctl( $daemon, "stop" );

                service_ctl( "pfdetect", "start" ) if ( $daemon eq "snort" || $daemon eq "suricata" );
                service_ctl( $daemon, "start" );
                last CASE;
            };
            $action eq "status" && do {
                my $pid;
                # -x: this causes the program to also return process id's of shells running the named scripts.
                if ($binary ne "pfdhcplistener") {
                    chomp( $pid = `pidof -x $binary` );
                    $pid = 0 if ( !$pid );
                    $logger->info("pidof -x $binary returned $pid");
                    return ($pid);
                }
                # Handle the pfdhcplistener case. Grab exact interfaces where pfdhcplistner should run,
                # explicitly check process names per interface then return 0 to force a restart if one is missing.
                else {
                    my %int_to_pid = map { $_ => $FALSE } @listen_ints, @dhcplistener_ints;
                    $logger->debug( "Expecting $binary on interfaces: " . join(", ", keys %int_to_pid) );

                    my $dead_flag;
                    foreach my $interface (keys %int_to_pid) {
                        # -f: whole command line, -x: exact match (fixes #1545)
                        chomp($int_to_pid{$interface} = `pgrep -f -x "$binary: listening on $interface"`);
                        # if one check returned a false value ('' is false) then we failed the check
                        if (!$int_to_pid{$interface}) {
                            $dead_flag = $TRUE;
                            $logger->debug( "Missing $binary process on interface: $interface" );
                        }
                        # more than one running instance: fail
                        elsif ($int_to_pid{$interface} =~ /\n/) {
                            $logger->debug( "More than one $binary process running on interface: $interface" );
                            $dead_flag = $TRUE;
                        }
                    }

                    # outputs: a list of interface => pid, ... helpful for sysadmin and forensics
                    $logger->info(
                        sprintf( "$binary pids %s", join(", ", map { "$_ => $int_to_pid{$_}" } keys %int_to_pid) )
                    );

                    # return 0 if one is not working
                    return 0 if ($dead_flag);
                    # otherwise the list of pids
                    return join(" ", values %int_to_pid);
                }
            }
        }
    }
    else {
        $logger->logcroak("unknown service $binary (daemon: $daemon)!");
        return $FALSE;
    }
    return $TRUE;
}

=item * service_list

return an array of enabled services

=cut

sub service_list {
    my @services         = @_;
    my @finalServiceList = ();
    my @add_last;
    foreach my $service (@services) {
        if ( $service eq 'snort' || $service eq 'suricata' ) {
            # add suricata or snort to services to add last if enabled
            push @add_last, $service
                if (isenabled($Config{'trapping'}{'detection'}) && $Config{'trapping'}{'detection_engine'} eq $service);
        } elsif ( $service eq "radiusd" ) {
            push @finalServiceList, $service 
                if ( isenabled($Config{'services'}{'radiusd'}) );
        } elsif ( $service eq "pfdetect" ) {
            push @finalServiceList, $service
                if ( isenabled( $Config{'trapping'}{'detection'} ) );
        } elsif ( $service eq "pfredirect" ) {
            push @finalServiceList, $service
                if ( $Config{'ports'}{'listeners'} );
        } elsif ( $service eq "dhcpd" ) {
            push @finalServiceList, $service
                if ( (is_inline_enforcement_enabled() || is_vlan_enforcement_enabled())
                    && isenabled($Config{'services'}{'dhcpd'}) );
        } elsif ( $service eq "named" ) {
            push @finalServiceList, $service 
                if ( (is_inline_enforcement_enabled() || is_vlan_enforcement_enabled())
                    && isenabled($Config{'services'}{'named'}) );
        }
        elsif ( $service eq 'pfdhcplistener' ) {
            push @finalServiceList, $service if ( isenabled($Config{'network'}{'dhcpdetector'}) );
        }
        # other services are added as-is
        else {
            push @finalServiceList, $service;
        }
    }

    push @finalServiceList, @add_last;
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
            $violations{$violation}{'grace'} = normalize_time($violations{$violation}{'grace'});
        }

        if ( defined $violations{$violation}{'window'} && $violations{$violation}{'window'} ne "dynamic" ) {
            $violations{$violation}{'window'} = normalize_time($violations{$violation}{'window'});
        }

        # be careful of the way parameters are passed, whitelists, actions and triggers are expected at the end
        class_merge(
            $violation,
            $violations{$violation}{'desc'},
            $violations{$violation}{'auto_enable'},
            $violations{$violation}{'max_enable'},
            $violations{$violation}{'grace'},
            $violations{$violation}{'window'},
            $violations{$violation}{'vclose'},
            $violations{$violation}{'priority'},
            $violations{$violation}{'url'},
            $violations{$violation}{'max_enable_url'},
            $violations{$violation}{'redirect_url'},
            $violations{$violation}{'button_text'},
            $violations{$violation}{'enabled'},
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

Copyright (C) 2009-2012 Inverse inc.

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

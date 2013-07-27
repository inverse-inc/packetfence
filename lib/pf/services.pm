package pf::services;

=head1 NAME

pf::services - module to manage the PacketFence services and daemons.

=head1 DESCRIPTION

pf::services contains the functions necessary to control the different
PacketFence services and daemons. It also contains the functions used
to generate or validate some configuration files.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files: F<dhcpd_vlan.conf>,
F<networks.conf>, F<violations.conf> and F<switches.conf>.

Generate the following configuration files: F<dhcpd.conf>, F<named.conf>,
F<snort.conf>, F<httpd.conf>, F<snmptrapd.conf>.

=cut

use strict;
use warnings;

use File::Basename;
use IPC::Cmd qw[can_run run];
use Log::Log4perl;
use Readonly;
use Time::HiRes;
use Try::Tiny;
use UNIVERSAL::require;
use Proc::ProcessTable;
use List::Util qw(first);

use pf::config;
use pf::util;
use pf::node qw(nodes_registered_not_violators);
use pf::trigger qw(trigger_delete_all parse_triggers);
use pf::class qw(class_view_all class_merge);
use pf::services::apache;
use pf::services::dhcpd qw(generate_dhcpd_conf);
use pf::services::radiusd qw(generate_radiusd_conf);
use pf::services::snmptrapd qw(generate_snmptrapd_conf);
use pf::services::snort qw(generate_snort_conf);
use pf::services::suricata qw(generate_suricata_conf);
use pf::SwitchFactory;
use pf::violation_config;

Readonly our @ALL_SERVICES => (
    'pfdns', 'dhcpd', 'pfdetect', 'snort', 'suricata', 'radiusd',
    'httpd.webservices', 'httpd.admin', 'httpd.portal', 'snmptrapd',
    'pfsetvlan', 'pfdhcplistener', 'pfmon'
);

Readonly our @APACHE_SERVICES => (
    'httpd.webservices', 'httpd.admin', 'httpd.portal'
);

my $services = join("|", @ALL_SERVICES);
Readonly our $ALL_BINARIES_RE => qr/$services
    |apache2                                   # httpd on debian
    |freeradius                                # radiusd on debian
    |httpd.worker                              # mpm_worker apache version
    |httpd
$/x;

=head1 Globals

=over

=item service_launchers

sprintf-formatted strings that control how the services should be started.
    %1$s: is the binary (w/ full path)
    %2$s: optional parameters

=cut

my %service_launchers;
$service_launchers{'httpd'} = "%1\$s -f $conf_dir/httpd.conf";
$service_launchers{'httpd.webservices'} = "%1\$s -f $conf_dir/httpd.conf.d/httpd.webservices -D$OS";
$service_launchers{'httpd.admin'} = "%1\$s -f $conf_dir/httpd.conf.d/httpd.admin -D$OS";
$service_launchers{'httpd.portal'} = "%1\$s -f $conf_dir/httpd.conf.d/httpd.portal -D$OS";

$service_launchers{'pfdetect'} = "%1\$s -d -p $install_dir/var/alert &";
$service_launchers{'pfmon'} = '%1$s -d &';
$service_launchers{'pfdhcplistener'} = 'sudo %1$s -i %2$s -d &';
$service_launchers{'pfsetvlan'} = '%1$s -d &';
# TODO the following join on @listen_ints will cause problems with dynamic config reloading
$service_launchers{'dhcpd'} = "sudo %1\$s -lf $var_dir/dhcpd/dhcpd.leases -cf $generated_conf_dir/dhcpd.conf -pf $var_dir/run/dhcpd.pid " . join(" ", @listen_ints);
$service_launchers{'pfdns'} = '%1$s -d &';
$service_launchers{'snmptrapd'} = "%1\$s -n -c $generated_conf_dir/snmptrapd.conf -C -A -Lf $install_dir/logs/snmptrapd.log -p $install_dir/var/run/snmptrapd.pid -On";
$service_launchers{'radiusd'} = "sudo %1\$s -d $install_dir/raddb/";

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
    if ($daemon =~ /httpd\.(.*)/) {
        $service = ( $Config{'services'}{"httpd_binary"} || "$install_dir/sbin/$daemon" );
    }
    my $binary = basename($service);

    #Untaint Daemon
    $daemon =~ /^(.*)$/;
    $daemon = $1;

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

                if ( $daemon =~ /(dhcpd|snort|suricata|httpd|snmptrapd|radiusd)/ && !$quick )
                {
                    my $confname = "generate_" . $daemon . "_conf";
                    $logger->info(
                        "Generating configuration file for $binary ($confname)");
                    my %serviceHash = (
                        'dhcpd' => \&generate_dhcpd_conf,
                        'snort' => \&generate_snort_conf,
                        'suricata' => \&generate_suricata_conf,
                        'httpd' => \&generate_httpd_conf,
                        'httpd.webservices' => \&generate_httpd_conf,
                        'httpd.portal' => \&generate_httpd_conf,
                        'httpd.admin' => \&generate_httpd_conf,
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

                    if ( !( ($daemon eq 'pfdhcplistener' ) || ($daemon eq 'httpd') || ($daemon eq 'httpd.webservices') || ($daemon eq 'httpd.admin') || ($daemon eq 'httpd.portal') ) ) {
                        if ( $daemon eq 'dhcpd' ) {

                            # create var/dhcpd/dhcpd.leases if it doesn't exist
                            pf_run("touch $var_dir/dhcpd/dhcpd.leases") if (!-f $var_dir . '/dhcpd/dhcpd.leases');

                            manage_Static_Route(1);

                        } elsif ( $daemon eq 'radiusd' ) {
                            my $pid = service_ctl( $daemon, "status" );
                            # TODO: push all these per-daemon initialization into pf::services::...
                            require pf::freeradius;
                            require pf::ConfigStore::SwitchOverlay;
                            pf::freeradius::freeradius_populate_nas_config(\%pf::ConfigStore::SwitchOverlay::SwitchConfig);

                        }
                        if ($service_launchers{$daemon} =~ /^(.+)$/) {
                            my $cmd_line = sprintf($1, $service);
                            $logger->info("Starting $daemon with '$cmd_line'");
                            # FIXME lame taint-mode bypass
                            if ($service_launchers{$daemon} =~ /^(.+)$/) {
                                my $launch = $1;
                                my $cmd_line = sprintf($launch, $service);
                                $logger->info("Starting $daemon with '$cmd_line'");
                                # FIXME lame taint-mode bypass
                                if ($cmd_line =~ /^(.+)$/) {
                                    $cmd_line = $1;
                                    my $t0 = Time::HiRes::time();
                                    my $return_value = system($cmd_line);
                                    my $elapsed = Time::HiRes::time() - $t0;
                                    $logger->info(sprintf("Daemon %s took %.3f seconds to start.", $daemon, $elapsed));
                                    return $return_value;
                                }
                            }
                        }
                    } elsif ($daemon eq 'pfdhcplistener') {
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
                                    $logger->info(sprintf("Daemon %s took %.3f seconds to start.", $daemon, $elapsed));
                                }
                            }
                            return 1;
                        }
                    } elsif ($daemon eq 'httpd') {
                        foreach my $serv (@APACHE_SERVICES) {
                            next if ($serv eq "httpd.admin");
                            my $cmd_line = sprintf($service_launchers{$serv}, $service);
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
                    } elsif ($daemon =~ /httpd\.(.*)/) {
                        my $conf = $1;
                        my $cmd_line =  sprintf($service_launchers{$daemon}, $service);
                        if ($cmd_line =~ /^(.+)$/) {
                            $cmd_line = $1;
                            $logger->info( "Starting $daemon with '$cmd_line'" );
                            my $t0 = Time::HiRes::time();
                            system($cmd_line);
                            my $elapsed = Time::HiRes::time() - $t0;
                            $logger->info(sprintf("Daemon $daemon took %.3f seconds to start.", $elapsed));
                        }
                    }
                }
                last CASE;
            };
            $action eq "stop" && do {
                if ($daemon eq 'httpd') {
                    foreach my $serv (@APACHE_SERVICES) {
                        my $pid = service_ctl( $serv, "status" );
                        if ($pid) {
                            my $cmd = "sudo /bin/kill -TERM $pid";

                            #Untaint cmd
                            $cmd =~ /^(.*)$/;
                            $cmd = $1;
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
                            my $ppt;
                            my $proc = 0;
                            while ( ( ( $curWait < $maxWait )
                                && ( service_ctl( $daemon, "status" ) ne "0" ) ) && defined($proc) )
                            {
                                $ppt = new Proc::ProcessTable;
                                $proc = first { defined($_) } grep { $_->pid == $pid } @{ $ppt->table };
                                $logger->info("Waiting for $binary to stop ");
                                sleep(2);
                                $curWait++;
                            }
                            if ( -e $install_dir . "/var/run/$binary.pid" ) {
                                $logger->info("Removing $install_dir/var/run/$binary.pid");
                                unlink( $install_dir . "/var/run/$binary.pid" );
                            }
                        }
                    }
                } else {
                    my $pids = service_ctl( $daemon, "status" );
                    my @pid = split(' ', $pids);
                    foreach my $pid (@pid) {
                        if ($pid) {
                            my $cmd = "sudo /bin/kill -TERM $pid";

                            #Untaint cmd
                            $cmd =~ /^(.*)$/;
                            $cmd = $1;
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
                            my $ppt;
                            my $proc = 0;
                            while ( ( ( $curWait < $maxWait )
                                && ( service_ctl( $daemon, "status" ) ne "0" ) ) && defined($proc) )
                            {
                                $ppt = new Proc::ProcessTable;
                                $proc = first { defined($_) } grep { $_->pid == $pid } @{ $ppt->table };
                                $logger->info("Waiting for $binary to stop ");
                                sleep(2);
                                $curWait++;
                            }
                            if ( -e $install_dir . "/var/run/$binary.pid" ) {
                                $logger->info("Removing $install_dir/var/run/$binary.pid");
                                unlink( $install_dir . "/var/run/$binary.pid" );
                            }
                        }
                    }
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
                if (!( ($binary eq "pfdhcplistener") || ($daemon eq "httpd") || ($daemon eq "httpd.webservices") || ($daemon eq "httpd.admin") || ($daemon eq "httpd.portal") || ($daemon eq "snort") ) ) {
                    my $pid_file = "$install_dir/var/run/$daemon.pid";
                    if (-e $pid_file) {
                        chomp( $pid = `cat $pid_file`);
                    }
                    $pid = 0 if ( !$pid );
                    $logger->info("pidof -x $binary returned $pid");
                    if($pid && $pid =~ /^(.*)$/) {
                        $pid = $1;
                        unless (kill( 0,$pid)) {
                            $pid = 0;
                            $logger->info("removing stale pid file $pid_file");
                            unlink $pid_file;
                        }
                    }

                    return ($pid);
                }
                # Handle the pfdhcplistener case. Grab exact interfaces where pfdhcplistner should run,
                # explicitly check process names per interface then return 0 to force a restart if one is missing.
                elsif ($binary eq "pfdhcplistener") {
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
                    # REWORK: if there only one interface without a pfdhcplistener then the pid is 0
                    # result, you can have more than one pfdhcplistener per interface ?!
                    # return 0 if ($dead_flag);
                    $pid = join(" ", values %int_to_pid);
                    if ( $pid =~ m/\d+/) {
                        return $pid;
                    } else {
                        return 0;
                    }
                }
                elsif ($daemon =~ "httpd(.*)") {
                    $pid = 0;
                    if (-e "$install_dir/var/run/$daemon.pid") {
                        chomp( $pid = `cat $install_dir/var/run/$daemon.pid`);
                        my $ppt = new Proc::ProcessTable;
                        my $proc = first { defined($_) } grep { $_->pid == $pid } @{ $ppt->table };
                        if (!defined($proc)) {
                            unlink( $install_dir . "/var/run/$binary.pid" );
                            return(0);
                        }
                    }
                    return ($pid);
                }
                elsif ($daemon =~ "snort") {
                    $pid = 0;
                    if (defined $monitor_int) {
                        if (-e "$install_dir/var/run/${daemon}_${monitor_int}.pid") {
                            chomp( $pid = `cat $install_dir/var/run/${daemon}_${monitor_int}.pid`);
                            my $ppt = new Proc::ProcessTable;
                            my $proc = first { defined($_) } grep { defined $_ && $_->pid == $pid } @{ $ppt->table };
                            if (!defined($proc)) {
                                unlink( $install_dir . "/var/run/${daemon}_${monitor_int}.pid" );
                                return(0);
                            }
                        }
                    }
                    return ($pid);
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
        } elsif ( $service eq "dhcpd" ) {
            push @finalServiceList, $service
                if ( (is_inline_enforcement_enabled() || is_vlan_enforcement_enabled())
                    && isenabled($Config{'services'}{'dhcpd'}) );
        } elsif ( $service eq "pfdns" ) {
            push @finalServiceList, $service
                if ( (is_inline_enforcement_enabled() || is_vlan_enforcement_enabled())
                    && isenabled($Config{'services'}{'pfdns'}) );
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

            my $cmd = "sudo $full_path $add_del -net $network netmask " . $net{'netmask'} . " gw " . $net{'next_hop'};
            $cmd = untaint_chain($cmd);
            my @out = pf_run($cmd);
        }
    }
}

=item * read_violations_conf

=cut

sub read_violations_conf {
    pf::violation_config::readViolationConfigFile();
    return 1;
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

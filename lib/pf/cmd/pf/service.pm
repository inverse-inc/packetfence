package pf::cmd::pf::service;

=head1 NAME

pf::cmd::pf::service add documentation

=head1 SYNOPSIS

pfcmd service <service> [start|stop|restart|status|generateconfig|updatesystemd] [--ignore-checkup]

  stop/stop/restart specified service
  status returns PID of specified PF daemon or 0 if not running.

  --ignore-checkup will start the requested services even if the checkup fails

Services managed by PacketFence:

  api-frontend           | Golang daemon providing API
  fingerbank-collector   | Fingerprinting data collection daemon
  galera-autofix         | Automated recovery of Galera clusters
  haproxy-admin          | haproxy admin daemon
  haproxy-db             | haproxy database daemon
  haproxy-portal         | haproxy portal daemon
  httpd.aaa              | Apache AAA webservice
  httpd.admin_dispatcher | Admin GUI dispatcher
  httpd.dispatcher       | Captive portal dispatcher
  httpd.portal           | Apache Captive Portal
  httpd.webservices      | Apache Webservices
  firewalld              | PacketFence firewall rules
  kafka                  | Kafka service
  keepalived             | Virtual IP management
  mysql-probe            | MySQL probe service
  netdata                | Monitoring service
  ntlm-auth-api          | ntlm auth backend API used to authenticate a user on Windows AD
  pfacct                 | Netflow and Radius Accounting service
  pf                     | all services that should be running based on your config
  pfcron                 | PF Cron daemon
  pfdetect               | PF snort alert parser
  pfdhcp                 | dhcpd daemon
  pfdhcplistener         | PF DHCP monitoring daemon
  pfdns                  | DNS daemon
  pffilter               | PF conditions filtering daemon
  pfipset                | IPSET daemon
  pfldapexplorer         | PF ldap search daemon
  pfperl-api             | Perl daemon providing API
  pfpki                  | PKI daemon
  pfqueue-go             | PF queueing service
  pfqueue-backend        | PF queueing backend service
  pfsetacls              | ACL service daemon
  pfsso                  | Firewall SSO daemon
  pfstats                | PF statistics daemon
  proxysql               | proxysql daemon
  radiusd                | FreeRADIUS daemon
  radsniff               | radsniff daemon
  redis_ntlm_cache       | Redis for the NTLM cache
  redis_queue            | Redis for pfqueue
  snmptrapd              | SNMP trap receiver daemon
  tracking-config        | Tracking configuration change

=head1 DESCRIPTION

pf::cmd::pf::service

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use IO::Interactive qw(is_interactive);
use Term::ANSIColor;
our ($SERVICE_HEADER);
our $COLORS;
use pf::log;
use pf::file_paths qw($install_dir);
use pf::config qw(%Config);
use pf::config::util;
use pf::util;
use pf::util::console;
use pf::constants;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE $EXIT_SERVICES_NOT_STARTED $EXIT_FATAL);
use pf::services;
use List::MoreUtils qw(part any true all);
use pf::constants::services qw(JUST_MANAGED);
use pf::cluster;
use pf::firewalld;

my $logger = get_logger();

our %ACTION_MAP = (
    status  => \&statusOfService,
    start   => \&startService,
    stop    => \&stopService,
    restart => \&restartService,
    generateconfig => \&generateConfig,
    updatesystemd    => \&updateSystemd,
);

our $ignore_checkup = $FALSE;

sub parseArgs {
    my ($self) = @_;
    my ($service, $action, $option) = $self->args;
    return 0 unless defined $service && defined $action && exists $ACTION_MAP{$action};
    return 0 unless $service eq 'pf' || any { $_ eq $service} @pf::services::ALL_SERVICES;

    my ( @services, @managers );
    if (($action eq 'updatesystemd' || $action eq 'generateconfig') && $service eq 'pf') {
        @services = grep {$_ ne 'pf'} @pf::services::ALL_SERVICES;
    } else {
        if($cluster_enabled && $service eq 'pf') {
            if ($action eq 'status') {
                @services = ($service);
            } else {
                @services = ('proxysql','haproxy-db','pf');
            }
        }
        else {
            @services = ($service);
        }
    }
    $self->{service}  = $service;
    $self->{services} = \@services;
    $self->{action}   = $action;
    $ignore_checkup = $TRUE if(defined($option) && $option eq '--ignore-checkup');
    return 1;
}

sub _run {
    my ($self) = @_;
    my $service = $self->{service};
    my $services = $self->{services};
    my $action = $self->{action};
    $SERVICE_HEADER ="service|command\n";
    $COLORS = pf::util::console::colors();
    my $actionHandler;
    $action =~ /^(.*)$/;
    $action = $1;
    $actionHandler = $ACTION_MAP{$action};
    $service =~ /^(.*)$/;
    $service = $1;
    # On pfcmd pf status we don't want to run updatesystemd
    # On pfcmd pf updatesystemd we don't want to run it twice
    if ($service eq 'pf' && ($action ne 'status' && $action ne 'updatesystemd')) {
        updateSystemd->($service, grep {$_ ne 'pf'} @pf::services::ALL_SERVICES);
    }
    my $output = "Service";
    $output .= (" " x 49);
    print "$COLORS->{status}${output}Status    PID$COLORS->{reset}\n" if  ($action ne 'updatesystemd' && $action ne 'generateconfig');
    return $actionHandler->($service,@$services);
}


sub startService {
    my ($service,@services) = @_;
    use sort qw(stable);
    my @managers = pf::services::getManagers(\@services,JUST_MANAGED);

    if ( !@managers ) {
        print "Service '$service' is not managed by PacketFence. Therefore, no action will be performed\n";
        return $EXIT_SUCCESS;
    }

    my $count = 0;

    my ($noCheckupManagers,$checkupManagers) = part { $_->shouldCheckup } @managers;

    if($noCheckupManagers && @$noCheckupManagers) {
        foreach my $manager (@$noCheckupManagers) {
            _doStart($manager);
        }
    }
    # Just before the checkup we make sure that the configuration is correct in the cluster if applicable
    
    if($cluster_enabled && $service eq 'pf') {
        pf::cluster::handle_config_conflict();
    }

    if($checkupManagers && @$checkupManagers) {
        checkup( map {$_->name} @$checkupManagers);
        foreach my $manager (@$checkupManagers) {
            if ($manager->isManaged()) {
                _doStart($manager);
                _doStopSubServices() if ($manager->name eq 'pf');
            } else {
                _doUpdateSystemd($manager, $TRUE);
                # Force stop
                $manager->stop;
            }
        }
    }
    return $EXIT_SUCCESS;
}

sub generateConfig {
    my ($service, @services) = @_;
    use sort qw(stable);
    my @managers = pf::services::getManagers(\@services);
    print $SERVICE_HEADER;
    for my $manager (@managers) {
        _doGenerateConfig($manager);
    }
    return $EXIT_SUCCESS;
}

sub updateSystemd {
    my ( $service, @services ) = @_;
    my @managers = pf::services::getManagers( \@services );
    my $show = $FALSE;
    if ($service ne 'pf') {
        print $SERVICE_HEADER;
        $show = $TRUE;
    }
    for my $manager (@managers) {
        _doUpdateSystemd($manager, $show);
    }
    if(isenabled($Config{monit}{status})) {
        system("sudo systemctl enable monit")
    } else {
        system("sudo systemctl disable monit")
    }
    system("sudo systemctl daemon-reload");
    return $EXIT_SUCCESS;
}


sub checkup {
    require pf::services;
    require pf::pfcmd::checkup;
    no warnings "once"; #avoids only used once warnings generated by the access of pf::pfcmd::checkup namespace
    my @services;
    if(@_) {
        @services = @_;
    } else {
        @services = @pf::services::ALL_SERVICES;
    }

    print "Checking configuration sanity...\n";
    my @problems = pf::pfcmd::checkup::sanity_check(pf::services::service_list(@services));
    foreach my $entry (@problems) {
        chomp $entry->{$pf::pfcmd::checkup::MESSAGE};
        print $entry->{$pf::pfcmd::checkup::SEVERITY}  . " - " . $entry->{$pf::pfcmd::checkup::MESSAGE} . "\n";
    }

    # if there is a fatal problem, exit with status 255
    foreach my $entry (@problems) {
        if (!$ignore_checkup && $entry->{$pf::pfcmd::checkup::SEVERITY} eq $pf::pfcmd::checkup::FATAL) {
            exit($EXIT_FATAL);
        }
    }

    if (@problems) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

sub _doStopSubServices {
    my @services = grep {$_ ne 'pf'} @pf::services::ALL_SERVICES;
    my @managers = pf::services::getManagers(\@services);
    foreach my $manager (@managers) {
        if (!$manager->isManaged()) {
            $manager->stop();
        }
    }
}

sub _doStart {
    my ($manager) = @_;
    if($manager->status ne '0' && $manager->name ne 'pf') {
        $manager->print_status;
    } else {
        $manager->start;
        $manager->print_status;
    }
}

sub _doGenerateConfig {
    my ($manager) = @_;
    my $command;
    my $color = '';
    if($manager->generateConfig()) {
        $command = 'config generated';
        $color =  $COLORS->{success};
    } else {
        $command = 'config not generated';
        $color =  $COLORS->{error};
    }
    print $manager->name,"|${color}${command}$COLORS->{reset}\n";
}

sub _doUpdateSystemd {
    my ($manager, $show) = @_;
    my $command;
    my $color = '';
    if ( $manager->isManaged ) {
        if ( $manager->sysdEnable() ) {
            $command = 'Service enabled';
            $color =  $COLORS->{success};
        }
        else {
            $command = 'Service not enabled';
            $color =  $COLORS->{error};
        }
    }
    else {
        if ( $manager->sysdDisable() ) {
            $command = 'Service disabled';
            $color =  $COLORS->{success};
        }
        else {
            $command = 'Service not disabled';
            $color =  $COLORS->{error};
        }
    }
    my $service = "packetfence-".$manager->name.".service";
    $service .= (" " x (50 - length($service)));
    print "$service\t${color}${command}$COLORS->{reset}\n" if $show;
}

sub stopService {
    my ($service,@services) = @_;
    my @managers = pf::services::getManagers(\@services);

    foreach my $manager (@managers) {
        if($manager->status eq '0') {
            $manager->print_status;
        } else {
            $manager->stop;
            $manager->print_status;
        }
    }
    if(isFirewalldManaged($service)) {
        my $count = true { $_->status eq '0'  } @managers;
        if( $count ) {
            fd_generate_pfconf_configs();
            fd_generate_dynamic_configs();
        } else {
            $logger->error(
                "Even though 'service pf stop' was called, there are still $count services running."
            );
        }
    }
    return $EXIT_SUCCESS;
}

sub isFirewalldManaged {
   return $_[0] eq 'pf' && isenabled($Config{services}{firewalld})
}

sub statusOfService {
    my ($service,@services) = @_;
    my @managers = pf::services::getManagers(\@services);
    foreach my $manager (@managers) {
        $manager->print_status;
    }
}

sub restartService {
    local $SERVICE_HEADER = '';
    return _restartService(@_);
}

sub _doRestart {
    my ($manager) = @_;
    $manager->restart;
    $manager->print_status;
}

sub _restartService {
    my ($service,@services) = @_;
    use sort qw(stable);
    my @managers = pf::services::getManagers(\@services,JUST_MANAGED);

    if ( !@managers ) {
        print "Service '$service' is not managed by PacketFence. Therefore, no action will be performed\n";
        return $EXIT_SUCCESS;
    }

    my $count = 0;

    my ($noCheckupManagers,$checkupManagers) = part { $_->shouldCheckup } @managers;

    if($noCheckupManagers && @$noCheckupManagers) {
        foreach my $manager (@$noCheckupManagers) {
            _doRestart($manager);
        }
    }

    if($cluster_enabled && $service eq 'pf') {
        pf::cluster::handle_config_conflict();
    }

    if($checkupManagers && @$checkupManagers) {
        checkup( map {$_->name} @$checkupManagers);
        foreach my $manager (@$checkupManagers) {
            if ($manager->isManaged()) {
                _doRestart($manager);
                _doStopSubServices() if ($manager->name eq 'pf');
            } else {
                _doUpdateSystemd($manager, $TRUE);
                # Force stop
                $manager->stop;
            }
        }
    }
    return $EXIT_SUCCESS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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


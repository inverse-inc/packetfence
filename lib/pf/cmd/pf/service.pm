package pf::cmd::pf::service;
=head1 NAME

pf::cmd::pf::service add documentation

=head1 SYNOPSIS

pfcmd service <service> [start|stop|restart|status|generateconfig|updatesystemd] [--ignore-checkup]

  stop/stop/restart specified service
  status returns PID of specified PF daemon or 0 if not running.

  --ignore-checkup will start the requested services even if the checkup fails

Services managed by PacketFence:

  carbon-cache        | carbon-cache daemon
  carbon-relay        | carbon-relay daemon
  collectd            | collectd daemon
  fingerbank-collector| Fingerbank device profiling collector
  haproxy             | haproxy daemon
  httpd.aaa           | Apache AAA webservice
  httpd.admin         | Apache Web admin
  httpd.collector     | Apache Collector daemon
  httpd.dispatcher    | Captive portal dispatcher
  httpd.graphite      | Apache Graphite daemon
  httpd.parking       | Apache Parking Portal
  httpd.portal        | Apache Captive Portal
  httpd.proxy         | Apache Proxy Interception
  httpd.webservices   | Apache Webservices
  iptables            | PacketFence firewall rules
  keepalived          | Virtual IP management
  pf                  | all services that should be running based on your config
  pfbandwidthd        | A pf service to monitor bandwidth usages
  pfdetect            | PF snort alert parser
  pfdhcp              | dhcpd daemon
  pfdhcplistener      | PF DHCP monitoring daemon
  pfdns               | DNS daemon
  pfipset             | IPSET daemon
  pffilter            | PF conditions filtering daemon
  pfmon               | PF monitoring daemon
  pfqueue             | PF queueing service
  pfsetvlan           | PF VLAN isolation daemon
  radiusd             | FreeRADIUS daemon
  radsniff            | radsniff daemon
  redis_ntlm_cache    | Redis for the NTLM cache
  redis_queue         | Redis for pfqueue
  routes              | manage static routes
  snmptrapd           | SNMP trap receiver daemon
  statsd              | statsd service
  winbindd            | Winbind daemon

=head1 DESCRIPTION

pf::cmd::pf::service

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use IO::Interactive qw(is_interactive);
use Term::ANSIColor;
our ($SERVICE_HEADER, $IS_INTERACTIVE);
our ($RESET_COLOR, $WARNING_COLOR, $ERROR_COLOR, $SUCCESS_COLOR);
use pf::log;
use pf::file_paths qw($install_dir);
use pf::config qw(%Config);
use pf::config::util;
use pf::util;
use pf::constants;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE $EXIT_SERVICES_NOT_STARTED $EXIT_FATAL);
use pf::services;
use List::MoreUtils qw(part any true all);
use pf::constants::services qw(JUST_MANAGED);
use pf::cluster;

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
    if ($service eq 'pf' ) {
        @services = @pf::services::ALL_SERVICES;
    }
    else {
        @services = ($service);
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
    $IS_INTERACTIVE = is_interactive();
    $RESET_COLOR =  $IS_INTERACTIVE ? color 'reset' : '';
    $WARNING_COLOR = $IS_INTERACTIVE ? color $YELLOW_COLOR : '';
    $ERROR_COLOR = $IS_INTERACTIVE ? color $RED_COLOR : '';
    $SUCCESS_COLOR = $IS_INTERACTIVE ? color $GREEN_COLOR : '';
    my $actionHandler;
    $action =~ /^(.*)$/;
    $action = $1;
    $actionHandler = $ACTION_MAP{$action};
    $service =~ /^(.*)$/;
    $service = $1;
    return $actionHandler->($service,@$services);
}

sub postPfStartService {
    my ($managers) = @_;
    my $count = true {$_->status ne '0'} @$managers;
    pf::config::configreload(1) unless $count;
}


sub startService {
    my ($service,@services) = @_;
    use sort qw(stable);
    my @managers = pf::services::getManagers(\@services,JUST_MANAGED);

    if ( !@managers ) {
        print "Service '$service' is not managed by PacketFence. Therefore, no action will be performed\n";
        return $EXIT_SUCCESS;
    }

    print $SERVICE_HEADER;

    my $count = 0;
    postPfStartService(\@managers) if $service eq 'pf';

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
            _doStart($manager);
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
    print $SERVICE_HEADER;
    for my $manager (@managers) {
        _doUpdateSystemd($manager);
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

sub _doStart {
    my ($manager) = @_;
    my $command;
    my $color = '';
    if($manager->status ne '0') {
        $color =  $WARNING_COLOR;
        $command = 'already started';
    } else {
        if($manager->start) {
            $command = 'start';
            $color =  $SUCCESS_COLOR;
        } else {
            $command = 'not started';
            $color =  $ERROR_COLOR;
        }
    }
    print $manager->name,"|${color}${command}${RESET_COLOR}\n";
}

sub _doGenerateConfig {
    my ($manager) = @_;
    my $command;
    my $color = '';
    if($manager->generateConfig()) {
        $command = 'config generated';
        $color =  $SUCCESS_COLOR;
    } else {
        $command = 'config not generated';
        $color =  $ERROR_COLOR;
    }
    print $manager->name,"|${color}${command}${RESET_COLOR}\n";
}

sub _doUpdateSystemd {
    my ($manager) = @_;
    my $command;
    my $color = '';
    if ( $manager->isManaged ) {
        if ( $manager->sysdEnable() ) {
            $command = 'Service enabled';
            $color   = $SUCCESS_COLOR;
        }
        else {
            $command = 'Service not enabled';
            $color   = $ERROR_COLOR;
        }
    }
    else {
        if ( $manager->sysdDisable() ) {
            $command = 'Service disabled';
            $color   = $SUCCESS_COLOR;
        }
        else {
            $command = 'Service not disabled';
            $color   = $ERROR_COLOR;
        }
    }

    print $manager->name, "|${color}${command}${RESET_COLOR}\n";
}

sub getIptablesTechnique {
    require pf::inline::custom;
    my $iptables = pf::inline::custom->new();
    return $iptables->{_technique};
}

sub stopService {
    my ($service,@services) = @_;
    my @managers = pf::services::getManagers(\@services);

    print $SERVICE_HEADER;
    foreach my $manager (@managers) {
        my $command;
        my $color = '';
        if($manager->status eq '0') {
            $command = 'already stopped';
            $color =  $WARNING_COLOR;
        } else {
            if($manager->stop) {
                $color =  $SUCCESS_COLOR;
                $command = 'stop';
            } else {
                $color =  $ERROR_COLOR;
                $command = 'not stopped';
            }
        }
        print $manager->name,"|${color}${command}${RESET_COLOR}\n";
    }
    if(isIptablesManaged($service)) {
        my $count = true { $_->status eq '0'  } @managers;
        if( $count ) {
            getIptablesTechnique->iptables_restore( $install_dir . '/var/iptables.bak' );
        } else {
            $logger->error(
                "Even though 'service pf stop' was called, there are still $count services running. "
                 . "Can't restore iptables from var/iptables.bak"
            );
        }
    }
    return $EXIT_SUCCESS;
}

sub isIptablesManaged {
   return $_[0] eq 'pf' && isenabled($Config{services}{iptables})
}

sub restartService {
    stopService(@_);
    local $SERVICE_HEADER = '';
    return startService(@_);
}

sub statusOfService {
    my ($service,@services) = @_;
    my @managers = pf::services::getManagers(\@services);
    print "service|shouldBeStarted|pid\n";
    my $notStarted = 0;
    foreach my $manager (@managers) {
        my $color = '';
        my $isManaged = $manager->isManaged;
        my $status = $manager->status;
        if($status eq '0' ) {
            if ($isManaged && !$manager->optional) {
                $color =  $ERROR_COLOR;
                $notStarted++;
            } else {
                $color =  $WARNING_COLOR;
            }
        } else {
            $color =  $SUCCESS_COLOR;
        }
        print $manager->name,"|${color}$isManaged|$status${RESET_COLOR}\n";
    }
    return ( $notStarted ? $EXIT_SERVICES_NOT_STARTED : $EXIT_SUCCESS)
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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


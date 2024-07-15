package pfappserver::Model::Config::System;

=head1 NAME

pfappserver::Model::Config::System - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;
use namespace::autoclean;
use Net::Netmask;

use pf::log;
use pf::error qw(is_error is_success);
use pf::util;

our $DB_SERVICE_NAME = "packetfence-mariadb";

extends 'Catalyst::Model';

=head1 METHODS

=head2 check_mysqld_status

=cut

sub check_mysqld_status {
    my ( $self ) = @_;
    my $logger = get_logger();
    my $cmd = "systemctl show -p MainPID $DB_SERVICE_NAME";
    # -x: this causes the program to also return process id's of shells running the named scripts.
    my $mainpid;
    chomp($mainpid = `$cmd`);
    my (undef,$pid) = split('=', $mainpid);
    $pid = 0 if ( !$pid );
    $logger->info("$cmd returned $pid");

    return ($pid);
}

=head2 getDefaultGateway

=cut

sub getDefaultGateway {
    my ($self) = @_;
    my $logger = get_logger();

    my $default_gateway = (split(" ", `LANG=C sudo ip route show to 0/0`))[2];
    $logger->debug("Default gateway: " . $default_gateway);

    return $default_gateway if defined($default_gateway);
}

=head2 getInterfaceForGateway

=cut

sub getInterfaceForGateway {
    my ( $self, $interfaces_ref, $gateway ) = @_;
    my $logger = get_logger();

    foreach my $interface ( sort keys(%$interfaces_ref) ) {
        next if ( !($interfaces_ref->{$interface}->{'is_running'}) );

        my $network = $interfaces_ref->{$interface}->{'network'};
        my $netmask = $interfaces_ref->{$interface}->{'netmask'};

        next if(!defined($network) or !defined($netmask));

        my $subnet  = new Net::Netmask($network, $netmask);

        return $interface if ( $subnet->match($gateway) );
    }

    return;
}

=head2 setDefaultRoute

=cut

sub setDefaultRoute {
    my ($self, $gateway) = @_;
    my $logger = get_logger();

    my $_EXIT_CODE_EXISTS = 7;

    my ($status, $status_msg);

    # Check for valid IP format
    if ( !valid_ip($gateway) ) {
        $status_msg = "Invalid IP format for gateway";
        $logger->warn("$status_msg");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    my $cmd = "sudo ip route replace to default via $gateway 2>&1";
    $logger->debug("Replace default gateway: $cmd");
    $status = safe_pf_run(qw(sudo ip route replace to default via), $gateway , {accepted_exit_status => [ $_EXIT_CODE_EXISTS ]});

    # Everything goes as expected
    if (defined($status)) {
        $status_msg = "New default gateway successfully injected";
        $logger->info($status_msg);
        return ($STATUS::OK, $status_msg);
    }
    # Something went wrong
    else {
        $status_msg = "Something went wrong while injecting default gateway";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
}

=head2 start_mysqld_service

=cut

sub start_mysqld_service {
    my ( $self ) = @_;
    my $logger = get_logger();

    my ($status, $status_msg);

    # Check to make sure that MySQLd is not already running
    if ( $self->check_mysqld_status ) {
        $status_msg = "MySQL server seems to be already running, did not started it";
        $logger->info($status_msg);
        return ($STATUS::OK, $status_msg);
    }

    # please keep LANG=C in case we need to fetch the output of the command
    my $cmd = "setsid sudo service $DB_SERVICE_NAME start 2>&1";
    $logger->debug("Starting $DB_SERVICE_NAME service: $cmd");
    $status = safe_pf_run(qw(setsid sudo service), $DB_SERVICE_NAME, 'start');

    # Everything goes as expected
    if ( defined($status) ) {
        $status_msg = "MySQL server successfully started";
        $logger->info($status_msg);
        return ($STATUS::OK, $status_msg);
    }
    # Something went wrong
    else {
        $status_msg = "Something went wrong while starting MySQL server";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
}

=head2 restart_pfconfig

=cut

sub restart_pfconfig {
    my ( $self ) = @_;
    my $logger = get_logger();

    my ($status, $status_msg);

    my $cmd = "setsid sudo service packetfence-config restart 2>&1";
    $logger->debug("Restarting packetfence-config service: $cmd");
    $status = safe_pf_run(qw(setsid sudo service packetfence-config restart));

    # Everything goes as expected
    if ( defined($status) ) {
        $status_msg = "packetfence-config successfully restarted";
        $logger->info($status_msg);
        return ($STATUS::OK, $status_msg);
    }
    # Something went wrong
    else {
        $status_msg = "Something went wrong while restarting packetfence-config";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
}

=head2 write_network_persistent

=cut

sub write_network_persistent {
    my ( $self, $interfaces_ref, $gateway ) = @_;
    my $logger = get_logger();

    my ($status, $status_msg, $systemObj);

    # Check if gateway is valid
    my $gateway_interface = $self->getInterfaceForGateway($interfaces_ref, $gateway);
    if ( !$gateway_interface ) {
        $status_msg = "Invalid gateway. Doesn't belong to any running and configured interface";
        $logger->error("$status_msg");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Inject gateway for live usage
    ($status, $status_msg) = $self->setDefaultRoute($gateway);
    if ( is_error($status) ) {
        $logger->error("$status_msg");
        return ($status, $status_msg);
    }

    # Instantiate an object for the correct OS
    ($status, $systemObj) = pfappserver::Model::Config::SystemFactory->getSystem();
    return ($status, $systemObj) if ( is_error($status) );

    # Write persistent network configurations
    ($status, $status_msg) = $systemObj->writeNetworkConfigs($interfaces_ref, $gateway, $gateway_interface);
    return ($status, $status_msg) if ( is_error($status) );

    $status_msg = "Persistent network configurations successfully written";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
}


package pfappserver::Model::Config::SystemFactory;


=head2 NAME

pfappserver::Model::Config::SystemFactory

=head2 DESCRIPTION

Moose class.

=cut

use Moose;
use pf::log;
use pf::util;

=head1 METHODS

=head2 _checkOs

Checks running operating system

=cut

sub _checkOs {
    my ( $self ) = @_;

    # Default to undef
    my $os;

    return ucfirst(host_os_detection());
}

=head2 getSystem

Obtain a system object suited for your system.

=cut

sub getSystem {
    my ( $self ) = @_;
    my $logger = get_logger();

    my $status_msg;

    my $os = $self->_checkOs();

    if (defined($os)) {
        my $system = "pfappserver::Model::Config::System::$os";
        my $systemObj = $system->new();
        $logger->info("Instantiate a new object of type $os");
        return ($STATUS::OK, $systemObj);
    }

    $status_msg = "This OS is not supported by PacketFence";
    $logger->error("$status_msg | Cannot instantiate an object of this type");

    return ($STATUS::NOT_IMPLEMENTED, $status_msg);
}


package pfappserver::Model::Config::System::Role;


=head2 NAME

pfappserver::Model::Config::System::Role

=head2 DESCRIPTION

Moose class implemeting roles.

=cut

use Moose::Role;
use pf::log;

requires qw(writeNetworkConfigs);


package pfappserver::Model::Config::System::Rhel;

=head3 NAME

pfappserver::Model::Config::System::Rhel

=head3 DESCRIPTION

Moose class derivated from role for OS specific methods

=cut

use Moose;

use pf::util;
use pf::log;

with 'pfappserver::Model::Config::System::Role';

our $_network_conf_dir    = "/etc/sysconfig/";
our $_interfaces_conf_dir = "network-scripts/";
our $_network_conf_file   = "network";
our $_interface_conf_file = "ifcfg-";
our $var_dir              = "/usr/local/pf/var/";

=head1 METHODS

=head2 writeNetworkConfigs

=cut

sub writeNetworkConfigs {
    my ( $self, $interfaces_ref, $gateway, $gateway_interface ) = @_;
    my $logger = get_logger();

    my $status_msg;
    my $interface_gateway;
    my $interface_defroute ="no";
    while (my ($interface, $interface_values) = each %$interfaces_ref) {
        next if ( !$interface_values->{is_running} );
        if ($gateway_interface eq $interface) {
            $interface_defroute = "yes";
            $interface_gateway = $gateway;
        } else {
            $interface_defroute = "no";
            $interface_gateway = undef;
        }
        my %vars = (
            logical_name => $interface,
            vlan_device  => $interface_values->{'vlan'},
            hwaddr       => $interface_values->{'hwaddress'},
            ipaddr       => $interface_values->{'ipaddress'},
            netmask      => $interface_values->{'netmask'},
            ipv6_address => $interface_values->{'ipv6_address'},
            ipv6_prefix  => $interface_values->{'ipv6_prefix'},
            defroute     => $interface_defroute,
            gateway      => $interface_gateway,
        );

        my $template = Template->new({
            INCLUDE_PATH    => "/usr/local/pf/html/pfappserver/root/interface",
            OUTPUT_PATH     => $var_dir,
        });
        my $outfile = $_interface_conf_file.$interface;

        $template->process( "interface_rhel.tt", \%vars, $outfile );

        if ( $template->error() ) {
            $status_msg = "Error while writing system network interfaces configuration";
            $logger->error("$status_msg");
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
        my $interface_config_file = "$_network_conf_dir$_interfaces_conf_dir$_interface_conf_file$interface";
        my $filter = variableExcludeRegex("$var_dir$outfile");
        my $cmd = "grep --no-filename -Pv '$filter' $interface_config_file >> $var_dir$outfile;cat $var_dir$outfile | sudo tee $interface_config_file 2>&1";
        my $status = pf_run($cmd);
        # Something went wrong
        if ( !(defined($status) ) ) {
            $status_msg = "Something went wrong while writing the network interface file";
            $logger->warn($status_msg);
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
    }

    if ( !(-e $_network_conf_dir.$_network_conf_file) ) {
        $status_msg = "Error while writing system's default gateway";
        $logger->error($status_msg ." | ". $_network_conf_dir.$_network_conf_file ." don't exists");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    open IN, '<', $_network_conf_dir.$_network_conf_file;
    my @content = <IN>;
    close IN;

    @content = grep { !/^GATEWAY=/ } @content;
    open(my $out, "|-", "sudo tee $_network_conf_dir$_network_conf_file > /dev/null");
    if (!$out) {
        $status_msg = "Something went wrong while writing the network file";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
    print $out @content;
    print $out "GATEWAY=$gateway\n";
    close $out;

    $logger->info("System network configurations successfully written");
    return $STATUS::OK;
}

sub variableExcludeRegex {
    my ($file) = @_;
    open IN, '<', $file;
    chomp(my @vars = <IN>);
    close IN;
    my @excludes = map { s/=.*//;$_ } grep { $_ ne ''  } @vars;
    return '^(?:(?:' . join('|', @excludes) . ')=|$)';
}

package pfappserver::Model::Config::System::Debian;


=head3 NAME

pfappserver::Model::Config::System::Debian

=head3 DESCRIPTION

Moose class derivated from role for OS specific methods

=cut

use Moose;

use pf::util;
use pf::log;

with 'pfappserver::Model::Config::System::Role';

our $_network_conf_dir    = "/etc/network/";
our $_network_conf_file   = "interfaces";
our $var_dir              ="/usr/local/pf/var/";

=head1 METHODS

=head2 writeNetworkConfigs

=cut

sub writeNetworkConfigs {
    my ( $self, $interfaces_ref, $gateway, $gateway_interface ) = @_;
    my $logger = get_logger();

    my $status_msg;

    my $vars = {
        interfaces          => $interfaces_ref,
        gateway             => $gateway,
        gateway_interface   => $gateway_interface,
    };

    my $template = Template->new({
        INCLUDE_PATH    => "/usr/local/pf/html/pfappserver/root/interface",
        OUTPUT_PATH     => $var_dir,
    });
    $template->process( "interface_debian.tt", $vars, $_network_conf_file ) || $logger->error($template->error());

    if ( $template->error() ) {
        $status_msg = "Error while writing system network interfaces configuration";
        $logger->error("$status_msg");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
    my $cmd = "cat $var_dir$_network_conf_file | sudo tee $_network_conf_dir$_network_conf_file 2>&1";
    my $status = pf_run($cmd);
    # Everything goes as expected
    if ( defined($status) ) {
        $status_msg = "Interface creation successfull";
        $logger->info($status_msg);
        return ($STATUS::OK, $status_msg);
    }
    # Something went wrong
    else {
        $status_msg = "Something went wrong while writing the network interface file";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

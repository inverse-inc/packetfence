package configurator::Model::Config::System;

=head1 NAME

configurator::Model::Config::System - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

=head1 METHODS

=over

=item write_network_persistent

=cut
sub write_network_persistent {
    my ( $self, $interface_ref, $gateway ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $status_msg, $systemObj);

    # Instantiate an object for the correct OS
    ($status, $systemObj) = configurator::Model::Config::SystemFactory->getSystem();
    return ($status, $systemObj) if ( is_error($status) );

    # Write persistent network interfaces configurations
    ($status, $status_msg) = $systemObj->writeInterfaceConfig($interface_ref);
    return ($status, $status_msg) if ( is_error($status) );

    # Write persistent system default gateway
    ($status, $status_msg) = $systemObj->writeGateway($gateway);
    return ($status, $status_msg) if ( is_error($status) );

    $status_msg = "Persistent network configurations successfully written";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
}


package configurator::Model::Config::SystemFactory;

=back

=head2 NAME

configurator::Model::Config::SystemFactory

=head2 DESCRIPTION

Moose class.

=cut

use Moose;

=head2 METHODS

=over

=item _checkOs

Checks running operating system

=cut
sub _checkOs {
    my ( $self ) = @_;

    # Default to undef
    my $os;

    # RedHat and derivatives
    $os = "RHEL" if ( -e "/etc/redhat-release" );
    # Debian and derivatives
    $os = "Debian" if ( -e "/etc/debian_version" );

    return $os;        
}

=item getSystem

Obtain a system object suited for your system.

=cut
sub getSystem {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    my $os = $self->_checkOs();

    $logger->info($os);
    if (defined($os)) {
        my $system = "configurator::Model::Config::System::$os";
        my $systemObj = $system->new();
        return ($STATUS::OK, $systemObj);
    }

    $status_msg = "This OS is not supported by PacketFence";
    $logger->error("$status_msg | Cannot instantiate an object of this type");

    return ($STATUS::NOT_IMPLEMENTED, $status_msg);
}


package configurator::Model::Config::System::Role;

=back

=head2 NAME

configurator::Model::Config::System::Role

=head2 DESCRIPTION

Moose class implemeting roles.

=cut

use Moose::Role;

requires qw(writeGateway writeInterfaceConfig);


package configurator::Model::Config::System::RHEL;

=head3 NAME

configurator::Model::Config::System::RHEL

=head3 DESCRIPTION

Moose class derivated from role for OS specific methods

=cut

use Moose;

with 'configurator::Model::Config::System::Role';

my $network_conf_dir    = "/etc/sysconfig/";
my $interfaces_conf_dir = "network-scripts/";
my $network_conf_file   = "network";
my $interface_conf_file = "ifcfg-";

=head3 METHODS

=over

=item writeGateway

=cut
sub writeGateway {
    my ( $this, $gateway ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $status_msg);

    if ( !(-e $network_conf_dir.$network_conf_file) ) {
        $status_msg = "Error while writing system's default gateway";
        $logger->error($status_msg ." | ". $network_conf_dir.$network_conf_file ." don't exists");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    open(CONF, ">>".$network_conf_dir.$network_conf_file);
    print CONF "\n GATEWAY=$gateway";
    close(CONF);

    return $STATUS::OK;
}

=item writeInterfaceConfig

=cut
sub writeInterfaceConfig {
    my ( $this, $interfaces_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    foreach my $interface ( sort keys(%$interfaces_ref) ) {
        next if ( !($interfaces_ref->{$interface}->{'running'}) );

        my $vars = {
            logical_name    => $interface,
            vlan_device     => $interfaces_ref->{$interface}->{'vlan'},
            hwaddr          => $interfaces_ref->{$interface}->{'hwaddress'},
            ipaddr          => $interfaces_ref->{$interface}->{'ipaddress'},
            netmask         => $interfaces_ref->{$interface}->{'netmask'},
        };

        my $template = Template->new({
            INCLUDE_PATH    => "/usr/local/pf/html/configurator/root/interface",
            OUTPUT_PATH     => $network_conf_dir.$interfaces_conf_dir,
        });
        $template->process( "interface_rhel.tt", $vars, $interface_conf_file.$interface );

        if ( $template->error() ) {
            $status_msg = "Error while writing system network interfaces configuration";
            $logger->error("$status_msg");
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        } 
    }

    $logger->info("System network interfaces successfully written");
    return $STATUS::OK;
}


package configurator::Model::Config::System::Debian;

=back

=head3 NAME

configurator::Model::Config::System::Debian

=head3 DESCRIPTION

Moose class derivated from role for OS specific methods

=cut

use Moose;

with 'configurator::Model::Config::System::Role';

my $network_conf_dir    = "/etc/network/";
my $network_conf_file   = "interfaces";

=head3 METHODS

=over

=item writeGateway

=cut
sub writeGateway {
    my ( $this, $gateway ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    die if ( !(-e $network_conf_dir.$network_conf_file) );

    open(CONF, ">>".$network_conf_dir.$network_conf_file);
    print CONF "\n gateway $gateway";
    close(CONF);
}

=item writeInterfaceConfig

=cut
sub writeInterfaceConfig {
    my ( $this, $interfaces_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    my $vars = {
        interfaces  => $interfaces_ref,
    };

    my $template = Template->new({
        INCLUDE_PATH    => "/usr/local/pf/html/configurator/root/interface",
        OUTPUT_PATH     => $network_conf_dir,
    });
    $template->process( "interface_debian.tt", $vars, $network_conf_file ) || $logger->error($template->error());

    if ( $template->error() ) {
        $status_msg = "Error while writing system network interfaces configuration";
        $logger->error("$status_msg");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    $logger->info("System network interfaces successfully written");
    return $STATUS::OK;
}

=back

=head1 AUTHORS

Olivier Bilodeau <obilodeau@inverse.ca>

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;

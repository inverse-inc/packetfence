package configurator::Model::Interface;

=head1 NAME

configurator::Model::Interface - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;

use HTTP::Status qw(:constants is_error is_success);
use IO::Interface::Simple;
use namespace::autoclean;
use Net::Netmask;

use pf::util;

extends 'Catalyst::Model';

=head1 METHODS

=over

=item create

=cut
sub create {
    my ( $self, $interface ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $status_msg);

    # This method does not handle the 'all' interface neither the 'lo' one
    return ($STATUS::FORBIDDEN, "This method does not handle interface $interface") 
        if ( ($interface eq 'all') || ($interface eq 'lo') );

    # Check if requested interface exists 
    ($status, $status_msg) = $self->exists($interface);
    if ( is_success($status) ) {
        $status_msg = "Interface VLAN $interface already exists";
        $logger->warn($status_msg);
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    my ($physical_interface, $vlan_id) = split( /\./, $interface );

    # Check if physical interface exists
    ($status, $status_msg) = $self->exists($physical_interface);
    if ( is_error($status) ) {
        $status_msg = "Physical interface $physical_interface does not exists so can't create VLAN interface on it";
        $logger->warn($status_msg);
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Create requested virtual interface
    my $cmd = "vconfig add $physical_interface $vlan_id";
    eval { $status = pf_run($cmd) };
    if ( $@ || !$status ) {
        $status_msg = "Error in creating interface VLAN $interface";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Might want to move this one in the controller... create doesn't invoke up...
    # Enable the newly created virtual interface
    $self->up($interface);

    return ($STATUS::OK, "Interface VLAN $interface successfully created");
}

=item delete

=cut
sub delete {
    my ( $self, $interface, $host ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $status_msg);

    # This method does not handle the 'all' interface neither the 'lo' one
    return ($STATUS::FORBIDDEN, "This method does not handle interface $interface")
        if ( ($interface eq 'all') || ($interface eq 'lo') );

    # Check if requested interface exists 
    ($status, $status_msg) = $self->exists($interface);
    if ( is_error($status) ) {
        $status_msg = "Interface VLAN $interface does not exists";
        $logger->warn($status_msg);
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Check if requested interface is virtual
    if ( !$self->_interfaceVirtual($interface) ) {
        $status_msg = "Interface $interface is not a virtual interface and cannot be deleted";
        $logger->warn($status_msg);
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Check if requested interface isn't currently in use
    if ( $self->_interfaceCurrentlyInUse($interface, $host) ) {
        $status_msg = "Interface VLAN $interface is currently in use for the configuration";
        $logger->warn($status_msg);
        return ($STATUS::FORBIDDEN, $status_msg);
    }

    # Delete requested virtual interface
    my $cmd = "vconfig rem $interface";
    eval { $status = pf_run($cmd) };
    if ( $@ || !$status ) {
        $status_msg = "Error in deletion of interface VLAN $interface";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, "Interface VLAN $interface successfully deleted");
}

=item down

=cut
sub down {
    my ( $self, $interface, $host ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $status_msg);

    # This method does not handle the 'all' interface neither the 'lo' one
    return ($STATUS::FORBIDDEN, "This method does not handle interface $interface")
        if ( ($interface eq 'all') || ($interface eq 'lo') );

    # Check if requested interface exists 
    ($status, $status_msg) = $self->exists($interface);
    if ( is_error($status) ) {
        $status_msg = "Interface $interface does not exists";
        $logger->warn($status_msg);
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Check if requested interface isn't already disabled
    if ( !$self->_interfaceActive($interface) ) {
        $status_msg = "Interface $interface is already disabled";
        $logger->warn($status_msg);
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Check if requested interface isn't currently in use
    if ( $self->_interfaceCurrentlyInUse($interface, $host) ) {
        $status_msg = "Interface $interface is currently in use for the configuration";
        $logger->warn("$status_msg | Is the interface correctly plugged in?");
        return ($STATUS::FORBIDDEN, $status_msg);
    }

    my $interface_object = IO::Interface::Simple->new($interface);
    my $flag = $interface_object->flags();

    # Check if interface flags exists
    if ( !$flag ) {
        $status_msg = "Something wen't wrong while fetching the interface current flag";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR);
    }

    # Flipping the 0x1 flag of the current network interface flags
    # This way, the interface will no longer be UP neither RUNNING
    $interface_object->flags($flag & ~0x1);

    # Check if interface is disabled
    # This check is necessary since the previous call (modification of the flag) does not return error or ok
    if ( $self->_interfaceActive($interface) ) {
        $status_msg = "Interface $interface has not been disabled. Should check server side logs for details";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, "Interface $interface successfully disabled");
}

=item edit

=cut
sub edit {
    my ( $self, $networksModel, $interface, $ipaddress, $netmask ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $status_msg);

    # This method does not handle the 'all' interface neither the 'lo' one
    return ($STATUS::FORBIDDEN, "This method does not handle interface $interface")
        if ( ($interface eq 'all') || ($interface eq 'lo') );

    # Check if requested interface exists 
    ($status, $status_msg) = $self->exists($interface);
    if ( is_error($status) ) {
        $status_msg = "Interface $interface does not exists";
        $logger->warn($status_msg);
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    my $interface_object = IO::Interface::Simple->new($interface);

    # Check if the network has changed
    my $network = $self->_get_network_address($interface_object->address, $interface_object->netmask);
    my $new_network = $self->_get_network_address($ipaddress, $netmask);
    if ($network ne $new_network) {
        $networksModel->update_network($network, $new_network);
    }

    # Edit IP address
    eval { $status = $interface_object->address($ipaddress) };
    if ( $@ || !$status ) {
        $status_msg = "Error in IP address $ipaddress while editing interface $interface";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Edit netmask
    eval { $status = $interface_object->netmask($netmask) };
    if ( $@ || !$status ) {
        $status_msg = "Error in netmask $netmask while editing interface $interface";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, "Interface $interface successfully edited");
}

=item exists

=cut
sub exists {
    my ( $self, $interface ) = @_;

    return ($STATUS::OK, "") if ( $interface eq 'all' );

    return ($STATUS::OK, "Interface $interface exists") if grep( /$interface/, $self->_listInterfaces() );

    return ($STATUS::NOT_FOUND, "Interface $interface does not exists");
}

=item get

Returns an hashref with:

    $interface => {
        name       => physical int (eth0 even if in a VLAN int)
        ipaddress  => ...
        netmask    => ...
        running    => true / false value
        network    => network address (ie 192.168.0.0 for a 192.168.0.1 IP)
    # and optionnally:
        vlan       => vlan tag
    }

Where $interface is physical interface if there's no VLAN interface (eth0)
and phy.vlan (eth0.100) if there's a vlan interface.

=cut
sub get {
    my ( $self, $interface ) = @_;

    # Put requested interfaces into an array
    my @interfaces;
    if ( $interface eq 'all' ) {
        @interfaces = $self->_listInterfaces();
    } else {
        @interfaces = (IO::Interface::Simple->new($interface));
    }

    my $result = {};
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    foreach $interface ( @interfaces ) {
        next if ( "$interface" eq "lo" );

        $result->{"$interface"}->{'name'}       = "$interface";
        $result->{"$interface"}->{'ipaddress'}  = $interface->address;
        $result->{"$interface"}->{'netmask'}    = $interface->netmask;
        $result->{"$interface"}->{'running'}    = $interface->is_running;
        if ((my ($physical_device, $vlan_id)    = $self->_interfaceVirtual($interface))) {
          $result->{"$interface"}->{'name'}     = $physical_device;
          $result->{"$interface"}->{'vlan'}     = $vlan_id;
        }
        $result->{"$interface"}->{'network'}    = $self->_get_network_address($interface->address, $interface->netmask);
    }

    return $result;
}

=item _get_network_address

Calculate the network address for the provided ipaddress/network combination

Returns undef on undef IP / Mask

=cut
sub _get_network_address {
    my ( $self, $ipaddress, $netmask ) = @_;

    return if ( !defined($ipaddress) || !defined($netmask) );
    return Net::Netmask->new($ipaddress, $netmask)->base();
}

=item _interfaceActive

Check if the requested interface is active or not on the system.

=cut
sub _interfaceActive {
    my ( $self, $interface ) = @_;

    my $interface_object = IO::Interface::Simple->new($interface);

    return $interface_object->is_running;
}

=item _interfaceCurrentlyInUse

=cut
sub _interfaceCurrentlyInUse {
    my ( $self, $interface, $host ) = @_;

    my $interface_ref = $self->get($interface);

    if ( $interface_ref->{$interface}->{'ipaddress'} =~ $host ) {
        return 1;
    }

    return 0;
}

=item _interfaceVirtual

=cut
sub _interfaceVirtual {
    my ( $self, $interface ) = @_;

    my ( $physical_device, $vlan_id ) = split( /\./, $interface );
    if ( !$vlan_id ) {
        return;
    }
 
    return ( $physical_device, $vlan_id );
}

=item _listInterfaces

Return a list of all curently installed network interfaces.

=cut
sub _listInterfaces {
    my ( $self ) = @_;

    my @interfaces_list = IO::Interface::Simple->interfaces;

    return @interfaces_list;
}

=item up

=cut
sub up {
    my ( $self, $interface ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $status_msg);

    # This method does not handle the 'all' interface neither the 'lo' one
    return ($STATUS::FORBIDDEN, "This method does not handle interface $interface")
        if ( ($interface eq 'all') || ($interface eq 'lo') );

    # Check if requested interface exists 
    ($status, $status_msg) = $self->exists($interface);
    if ( is_error($status) ) {
        $status_msg = "Interface $interface does not exists";
        $logger->warn($status_msg);
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Check if requested interface isn't already enabled
    if ( $self->_interfaceActive($interface) ) {
        $status_msg = "Interface $interface is already enabled";
        $logger->warn($status_msg);
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    my $interface_object = IO::Interface::Simple->new($interface);
    my $flag = $interface_object->flags();

    # Check if interface flags exists
    if ( !$flag ) {
        $status_msg = "Something wen't wrong while fetching the interface current flag";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR);
    }

    # Flipping the 0x1 flag of the current network interface flags
    # This way, the interface will switch to UP and RUNNING
    $interface_object->flags($flag | 0x1);

    # Check if interface is enabled
    # This check is necessary since the previous call (modification of the flag) does not return error or ok
    if ( !$self->_interfaceActive($interface) ) {
        $status_msg = "Interface $interface has not been enabled. Should check server side logs for details";
        $logger->error("$status_msg | Is the interface correctly plugged in?");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, "Interface $interface successfully enabled");
}

=back

=head1 AUTHORS

Derek Wuelfrath <dwuelfrath@inverse.ca>

Francis Lachapelle <flachapelle@inverse.ca>

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

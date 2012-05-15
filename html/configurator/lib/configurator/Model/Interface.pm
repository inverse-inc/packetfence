package configurator::Model::Interface;

=head1 NAME

configurator::Model::Interface - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

# Catalyst includes
use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";

# Package includes
use IO::Interface::Simple;

# PacketFence includes
use pf::util;


=head1 SUBROUTINES

=over

=item create

=cut
sub create {
    my ( $self, $interface ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;
    my $result;

    my ( $physical_device, $vlan_id ) = split( /\./, $interface );
    my $cmd = "vconfig add $physical_device $vlan_id";

    # This method does not handle the 'all' interface neither the 'lo' one
    if ( ($interface eq 'all') || ($interface eq 'lo') ) {
        $status_msg = "This method does not handle this interface: $interface";
        $logger->warn($status_msg);
        return $status_msg;
    }

    # Check if the requested interface doesn't already exists
    if ( $self->_interfaceExists($interface) ) {
        $status_msg = "Interface $interface already exists on the system";
        $logger->warn($status_msg);
        return $status_msg;
    }

    # Check if physical device exists
    if ( !$self->_interfaceExists($physical_device) ) {
        $status_msg = "Physical interface $physical_device does not exists so can't create VLAN interface on it";
        $logger->warn($status_msg);
        return $status_msg;
    }

    # Create virtual interface
    eval { $result = pf_run($cmd) };
    if ( $@ || !$result ) {
        $status_msg = "Error in creating virtual interface $interface";
        $logger->error($status_msg);
        return $status_msg;
    }

    # Enable the newly created virtual interface
    $self->up($interface);

    return 1;
}

=item delete

=cut
sub delete {
    my ( $self, $interface, $host ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;
    my $result;

    my $cmd = "vconfig rem $interface";

    # This method does not handle the 'all' interface neither the 'lo' one
    if ( ($interface eq 'all') || ($interface eq 'lo') ) {
        $status_msg = "This method does not handle this interface: $interface";
        $logger->warn($status_msg);
        return $status_msg;
    }

    # Check if the requested interface exists
    if ( !$self->_interfaceExists($interface) ) {
        $status_msg = "Interface $interface does not exists on the system";
        $logger->warn($status_msg);
        return $status_msg;
    }

    # Check if it is not the interface we're currently using
    if ( $self->_interfaceCurrentlyInUse($interface, $host) ) {
        $status_msg = "Interface $interface is currently in use for the configuration";
        return $status_msg;
    }

    # Check if the requested interface is a virtual interface
    if ( !$self->_interfaceVirtual($interface) ) {
        $status_msg = "Interface $interface is not a valid virtual interface";
        $logger->warn($status_msg);
        return $status_msg;
    }

    # Delete virtual interface
    eval { $result = pf_run($cmd) };
    if ( $@ || !$result ) {
        $status_msg = "Error in deletion of virtual interface $interface";
        $logger->error($status_msg);
        return $status_msg;
    }

    return 1;
}

=item down

=cut
sub down {
    my ( $self, $interface, $host ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    my $interface_object = IO::Interface::Simple->new($interface);
    my $flag = $interface_object->flags();

    # This method does not handle the 'all' interface neither the 'lo' one
    if ( ($interface eq 'all') || ($interface eq 'lo') ) {
        $status_msg = "This method does not handle this interface: $interface";
        $logger->warn($status_msg);
        return $status_msg;
    }

    # Check if interface isn't already active on the system
    if ( !$self->_interfaceActive($interface) ) {
        $status_msg = "Interface $interface is not active on the system";
        $logger->warn($status_msg);
        return $status_msg;
    }

    # Check if it is not the interface we're currently using
    if ( $self->_interfaceCurrentlyInUse($interface, $host) ) {
        $status_msg = "Interface $interface is currently in use for the configuration";
        return $status_msg;
    }

    # Check if interface flags exists
    if ( !$flag ) {
        $status_msg = "Something wen't wrong while fetching the interface current flag";
        $logger->error($status_msg);
        return $status_msg;
    }

    # Flipping the 0x1 flag of the current network interface flags
    # This way, the interface will switch will no longer be UP neither RUNNING
    $interface_object->flags($flag & ~0x1);

    return 1;
}

=item edit

=cut
sub edit {
    my ( $self, $interface, $ipaddress, $netmask ) = @_; 
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;
    my $result;

    my $interface_object = IO::Interface::Simple->new($interface);

    # This method does not handle the 'all' interface neither the 'lo' one
    if ( ($interface eq 'all') || ($interface eq 'lo') ) {
        $status_msg = "This method does not handle this interface: $interface";
        $logger->warn($status_msg);
        return $status_msg;
    }

    # Edit IP address
    eval { $result = $interface_object->address($ipaddress) };
    if ( $@ || !$result ) {
        $status_msg = "Error in IP address $ipaddress while editing interface $interface";
        $logger->error($status_msg);
        return $status_msg;
    }

    # Edit netmask
    eval { $result = $interface_object->netmask($netmask) };
    if ( $@ || !$result ) {
        $status_msg = "Error in netmask $netmask while editing interface $interface";
        $logger->error($status_msg);
        return $status_msg;
    }

    return 1;
}

=item get

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

        $result->{"$interface"}->{'name'}      = "$interface";
        $result->{"$interface"}->{'ipaddress'} = $interface->address;
        $result->{"$interface"}->{'netmask'}   = $interface->netmask;
        $result->{"$interface"}->{'running'}   = $interface->is_running;
        if ((my ($physical_device, $vlan_id) = $self->_interfaceVirtual($interface))) {
          $result->{"$interface"}->{'name'}    = $physical_device;
          $result->{"$interface"}->{'vlan'}    = $vlan_id;
        }
        #$result->{$interface}->{'type'} = 
    }

    return $result;
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

=item _interfaceExists

Check if the requested interface exists according to the list of currently installed interfaces.

=cut
sub _interfaceExists {
    my ( $self, $interface ) = @_;

    return 1 if ( $interface eq 'all' );

    my $exists = grep( /$interface/, $self->_listInterfaces() );

    return $exists;
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

    my $status_msg;

    my $interface_object = IO::Interface::Simple->new($interface);
    my $flag = $interface_object->flags();

    # This method does not handle the 'all' interface neither the 'lo' one
    if ( ($interface eq 'all') || ($interface eq 'lo') ) {
        $status_msg = "This method does not handle this interface: $interface";
        $logger->warn($status_msg);
        return $status_msg;
    }

    # Check if interface isn't already active on the system
    if ( $self->_interfaceActive($interface) ) {
        $status_msg = "Interface $interface is already active on the system";
        $logger->warn($status_msg);
        return $status_msg;
    }

    # Check if interface flags exists
    if ( !$flag ) {
        $status_msg = "Something wen't wrong while fetching the interface current flag";
        $logger->error($status_msg);
        return $status_msg;
    }

    # Flipping the 0x1 flag of the current network interface flags
    # This way, the interface will switch to UP and RUNNING
    $interface_object->flags($flag | 0x1);

    # Server must run as root
    unless ( $< == 0 ) {
        $status_msg = "The configurator must run under the root user.";
        $logger->error($status_msg);
        return $status_msg;
    }

    return 1;
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

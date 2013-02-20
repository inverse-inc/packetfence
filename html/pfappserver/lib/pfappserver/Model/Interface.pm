package pfappserver::Model::Interface;

=head1 NAME

pfappserver::Model::Interface - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;

use IO::Interface::Simple;
use namespace::autoclean;
use Net::Netmask;

use pf::error qw(is_error is_success);
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
        return ($STATUS::OK, $status_msg);
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

    return ($STATUS::CREATED, "Interface VLAN $interface successfully created");
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

=item exists

=cut
sub exists {
    my ( $self, $interface ) = @_;

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
        hwaddress  => mac address
        type       => enforcement type (see Enforcement model)
    # and optionnally:
        vlan       => vlan tag
        dns        => network dns
    }

Where $interface is physical interface if there's no VLAN interface (eth0)
and phy.vlan (eth0.100) if there's a vlan interface.

=cut
sub get {
    my ( $self, $interface, $models ) = @_;

    # Put requested interfaces into an array
    my @interfaces;
    if ( $interface eq 'all' ) {
        @interfaces = $self->_listInterfaces();
    } else {
        @interfaces = (IO::Interface::Simple->new($interface));
    }

    my $result = {};
    my ($status, $return);
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    foreach $interface ( @interfaces ) {
        next if ( "$interface" eq "lo" );

        $result->{"$interface"} = {};
        $result->{"$interface"}->{'name'}       = "$interface";
        $result->{"$interface"}->{'ipaddress'}  = $interface->address;
        $result->{"$interface"}->{'netmask'}    = $interface->netmask;
        $result->{"$interface"}->{'running'}    = $interface->is_running;
        if ((my ($physical_device, $vlan_id)    = $self->_interfaceVirtual($interface))) {
          $result->{"$interface"}->{'name'}     = $physical_device;
          $result->{"$interface"}->{'vlan'}     = $vlan_id;
        }
        $result->{"$interface"}->{'hwaddress'}  = $interface->hwaddr;
        if (($result->{"$interface"}->{'network'} = $models->{networks}->getNetworkAddress($interface->address, $interface->netmask))) {
            ($status, $return) = $models->{networks}->getRoutedNetworks($result->{"$interface"}->{'network'},
                                                                           $interface->netmask);
            if (is_success($status)) {
                $result->{"$interface"}->{'networks'} = $return;
            }
            ($status, $return) = $models->{networks}->read_value($result->{"$interface"}->{'network'}, 'dns');
            if (is_success($status)) {
                $result->{"$interface"}->{'dns'} = $return;
            }
            $result->{"$interface"}->{'network_iseditable'} = $models->{networks}->exist($result->{"$interface"}->{'network'});
        }
        $result->{"$interface"}->{'type'} = $self->getType($interface, $result->{"$interface"}, $models);
    }

    return $result;
}

=item update

=cut
sub update {
    my ( $self, $interface, $interface_ref, $models ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($ipaddress, $netmask, $status, $status_msg);

    $interface_ref->{netmask} = '255.255.255.0' unless ($interface_ref->{netmask});
    $ipaddress = $interface_ref->{ipaddress};
    $netmask = $interface_ref->{netmask};

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
    my $network = $models->{networks}->getNetworkAddress($interface_object->address, $interface_object->netmask);
    my $new_network = $models->{networks}->getNetworkAddress($ipaddress, $netmask);
    if ($network && $network ne $new_network) {
        $logger->debug("Network has changed for $ipaddress ($network => $new_network)");
        $models->{networks}->update_network($network, $new_network);
    }

    # Edit IP address
    eval { $status = $interface_object->address($ipaddress) };
    if ( $@ || !$status ) {
        $status_msg = "Error in IP address $ipaddress while editing interface $interface";
        $logger->error("$status_msg: $@");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Edit netmask
    eval { $status = $interface_object->netmask($netmask) };
    if ( $@ || !$status ) {
        $status_msg = "Error in netmask $netmask while editing interface $interface";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Set type
    $interface_ref->{network} = $new_network;
    $self->setType($interface_ref, $models);

    return ($STATUS::OK, "Interface $interface successfully edited");
}

=item isActive

=cut
sub isActive {
    my ( $self, $interface ) = @_;

    my @interfaces;
    if ( $interface eq 'all' ) {
        @interfaces = $self->_listInterfaces();
    } else {
        @interfaces = (IO::Interface::Simple->new($interface));
    }
    my %status = map { ($_->name eq 'lo') ? () : ($_->name => $_->is_running) } @interfaces;

    return \%status;
}

=item getType

=cut
sub getType {
    my ( $self, $interface, $interface_ref, $models ) = @_;

    my ($status, $type);
    if ($interface_ref->{'network'}) {
        # Check in networks.conf
        ($status, $type) = $models->{networks}->getType($interface_ref->{network});
        if ( is_error($status) ) {
            $type = undef;
        }
    }
    unless ($type) {
        # Check in pf.conf
        ($status, $type) = $models->{pf}->read_interface_value($interface, 'type');

        # if the interface is not defined in pf.conf
        if ( is_error($status) ) {
            $type = 'none';
        }
        # rely on pf.conf's info
        else {
            $type = ($type =~ /management|managed/i) ? 'management' : 'other';
        }
    }

    return $type;
}

=item setType

 Update networks.conf and pf.conf

=cut
sub setType {
    my ( $self, $interface_ref, $models ) = @_;

    my $interface = $interface_ref->{name};
    my $type = $interface_ref->{type} || 'none';

    # we ignore interface type 'Other' (it basically means unsupported in configurator)
    return if ( $type =~ /^other$/i );

    # we delete interface type 'None'
    if ( $type =~ /^none$/i ) {
        if ($models->{networks}->exist($interface_ref->{network})) {
            $models->{networks}->delete($interface_ref->{network});
        }
        if ($models->{pf}->exist_interface($interface)) {
            $models->{pf}->delete_interface($interface);
        }
    }
    # otherwise we update pf.conf and networks.conf
    else {
        # we willingly silently ignore errors if interface already exists
        # TODO have a wrapper that does both?
        $models->{pf}->create_interface($interface);
        $models->{pf}->update_interface($interface,
                                        $self->_prepare_interface_for_pfconf($interface, $interface_ref, $type));

        # FIXME refactor that!
        # and we must create a network portion for the following types
        if ( $type =~ /^vlan-isolation$|^vlan-registration$/i ) {
            $models->{networks}->create($interface_ref->{network});
            $models->{networks}->update($interface_ref->{network},
                                        {
                                         type => $type,
                                         netmask => $interface_ref->{'netmask'},
                                         # FIXME push these default values further down in the stack
                                         # (into pf::config, pf::services, etc.)
                                         gateway => $interface_ref->{'ipaddress'},
                                         dns => $interface_ref->{'ipaddress'},
                                         dhcp_start => Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(10),
                                         dhcp_end => Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(-10),
                                         dhcp_default_lease_time => 30,
                                         dhcp_max_lease_time => 30,
                                         named => 'enabled',
                                         dhcpd => 'enabled',
                                        }
                                       );
        }
        elsif ( $type =~ /^inline$/i ) {
            $models->{networks}->create($interface_ref->{network});
            $models->{networks}->update($interface_ref->{network},
                                        {
                                         type => $type,
                                         netmask => $interface_ref->{'netmask'},
                                         # FIXME push these default values further down in the stack
                                         # (into pf::config, pf::services, etc.)
                                         gateway => $interface_ref->{'ipaddress'},
                                         dns => $interface_ref->{'dns'},
                                         dhcp_start => Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(10),
                                         dhcp_end => Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(-10),
                                         dhcp_default_lease_time => 24 * 60 * 60,
                                         dhcp_max_lease_time => 24 * 60 * 60,
                                         named => 'enabled',
                                         dhcpd => 'enabled',
                                        }
                                       );
        }
        elsif ( $type =~ /^management$/ ) {
            # management interfaces must not appear in networks.conf
            if ($models->{networks}->exist($interface_ref->{network})) {
                $models->{networks}->delete($interface_ref->{network});
            }
        }
    }
}


sub interfaceForDestination {
    my ( $self, $destination ) = @_;

    my @interfaces = $self->_listInterfaces();

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    foreach my $interface ( @interfaces ) {
        next if ( "$interface" eq "lo" );

        if ($interface->address && $interface->netmask) {
            my $network = Net::Netmask->new($interface->address, $interface->netmask);
            if ($network->match($destination)) {
                return $interface;
            }
        }
    }
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

    my $interface_object = IO::Interface::Simple->new($interface);

    if ( $interface_object->address =~ $host ) {
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

=head2 _prepare_interface_for_pfconf

Process parameters to build a proper pf.conf interface section.

=cut
# TODO push hardcoded strings as constants (or re-use core constants)
# this might imply a rework of this out of the controller into the model
sub _prepare_interface_for_pfconf {
    my ($self, $int, $int_model, $type) = @_;

    my $int_config_ref = {
        ip => $int_model->{'ipaddress'},
        mask => $int_model->{'netmask'},
    };

    # logic to match our awkward relationship between pf.conf's type and
    # enforcement with networks.conf's type
    if ($type =~ /^vlan/i) {
        $int_config_ref->{'type'} = 'internal';
        $int_config_ref->{'enforcement'} = 'vlan';
    }
    elsif ($type =~ /^inline$/i) {
        $int_config_ref->{'type'} = 'internal';
        $int_config_ref->{'enforcement'} = 'inline';
    }
    else {
        # here we oversimplify a bit, type supports multivalues but it's
        # out of scope for now
        $int_config_ref->{'type'} = $type;
    }

    return $int_config_ref;
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

=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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

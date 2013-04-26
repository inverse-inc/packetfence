package pfappserver::Model::Interface;

=head1 NAME

pfappserver::Model::Interface - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;

use namespace::autoclean;
use Net::Netmask;

use pf::config;
use pf::error qw(is_error is_success);
use pf::util;

extends 'Catalyst::Model';

=head1 METHODS

=head2 create

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
    my $cmd = "LANG=C sudo vconfig add $physical_interface $vlan_id";
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

=head2 delete

=cut

sub delete {
    my ($self, $interface, $host, $models) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $status_msg);

    # This method does not handle the 'all' interface neither the 'lo' one
    return ($STATUS::FORBIDDEN, "This method does not handle interface $interface")
        if ( ($interface eq 'all') || ($interface eq 'lo') );

    # Retrieve interface definition
    my @results = $self->_listInterfaces($interface);
    my $interface_ref = pop @results;

    # Check if requested interface exists
    if (!defined $interface_ref) {
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
    my $cmd = "LANG=C sudo vconfig rem $interface";
    eval { $status = pf_run($cmd) };
    if ( $@ || !$status ) {
        $status_msg = "Error in deletion of interface VLAN $interface";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Delete corresponding interface entry from pf.conf
    $models->{interface}->remove($interface);

    # Remove associated network entries
    @results = $self->_listInterfaces('all');
    if ($models->{network}->cleanupNetworks(\@results)) {
        $models->{network}->rewriteConfig();
    }

    return ($STATUS::OK, "Interface VLAN $interface successfully deleted");
}

=head2 down

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

    # Disable interface using "ip"
    my $cmd = sprintf "LANG=C sudo ip link set %s down", $interface;
    eval { $status = pf_run($cmd) };
    if ( $@ ) {
        $status_msg = "Can't disable interface $interface: $status";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Check if interface is disabled
    # This check is necessary since the previous call (modification of the flag) does not return error or ok
    if ( $self->_interfaceActive($interface) ) {
        $status_msg = "Interface $interface has not been disabled. Should check server side logs for details";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, "Interface $interface successfully disabled");
}

=head2 exists

=cut

sub exists {
    my ($self, $interface) = @_;

    my @result = $self->_listInterfaces($interface);

    return ($STATUS::OK, "Interface $interface exists") if (scalar @result > 0);
    return ($STATUS::NOT_FOUND, "Interface $interface does not exists");
}

=head2 get

Returns an hashref with:

    $interface => {
        name       => physical int (eth0 even if in a VLAN int)
        ipaddress  => ...
        netmask    => ...
        is_running    => true / false value
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
    my @interfaces = $self->_listInterfaces($interface);
    my $networks_model = $models->{networks};

    my $result = {};
    my ($status, $return);
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    foreach my $interface_ref ( @interfaces ) {
        next if ( $interface_ref->{name} eq "lo" );

        $interface                              = $interface_ref->{name};
        $result->{"$interface"}                 = $interface_ref;
        if ((my ($physical_device, $vlan_id)    = $self->_interfaceVirtual($interface))) {
          $result->{"$interface"}->{'name'}     = $physical_device;
          $result->{"$interface"}->{'vlan'}     = $vlan_id;
        }
        if (($result->{"$interface"}->{'network'} = $networks_model->getNetworkAddress($interface_ref->{ipaddress}, $interface_ref->{netmask}))) {
            ($status, $return) = $networks_model->getRoutedNetworks($result->{"$interface"}->{'network'},
                                                                           $interface_ref->{netmask});
            if (is_success($status)) {
                $result->{"$interface"}->{'networks'} = $return;
            }
            my $network;
            ($status, $network) = $networks_model->read($result->{"$interface"}->{'network'});
            if (is_success($status)) {
                $result->{"$interface"}->{'dns'} = $network->{dns};
            }
            #($status, undef) = $networks_model->hasId($result->{"$interface"}->{'network'});
            $result->{"$interface"}->{'network_iseditable'} = is_success($status);
        }
        $result->{"$interface"}->{'type'} = $self->getType($interface_ref, $models);
    }

    return $result;
}

=head2 update

=cut

sub update {
    my ($self, $interface, $interface_ref, $models) = @_;
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

    my @result = $self->_listInterfaces($interface);
    my $interface_before = pop @result;

    # Check if the network has changed
    my $network = $models->{network}->getNetworkAddress($interface_before->{ipaddress}, $interface_before->{netmask});
    my $new_network = $models->{network}->getNetworkAddress($ipaddress, $netmask);
    if ($network && $new_network && $network ne $new_network) {
        $logger->debug("Network has changed for $ipaddress ($network => $new_network)");
        $models->{network}->renameItem($network, $new_network);
    }

    if ( !defined($interface_before->{ipaddress})
         || !defined($interface_before->{netmask})
         || !defined($ipaddress)
         || $ipaddress ne $interface_before->{ipaddress}
         || $netmask ne $interface_before->{netmask}) {
        my $gateway = $models->{system}->getDefaultGateway();
        my $isDefaultRoute = (defined($interface_before->{ipaddress}) && $gateway eq $interface_before->{ipaddress});

        # Delete previous IP address
        my $cmd;
        if (defined($interface_before->{address}) && $interface_before->{address} ne '') {
            $cmd = sprintf "LANG=C sudo ip addr del %s dev %s", $interface_before->{address}, $interface_before->{name};
            eval { $status = pf_run($cmd) };
            if ( $@ || $status ) {
                $status_msg = "Can't delete previous IP address of interface $interface (".$interface_before->{address}.")";
                $logger->error($status_msg);
                $logger->error("$cmd: $status");
                return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
            }
        }

        # Add new IP address and netmask
        if ($ipaddress && $ipaddress ne '') {
            my $block = Net::Netmask->new($ipaddress.':'.$netmask);
            my $broadcast = $block->broadcast();
            $netmask = $block->bits();

            $logger->debug("IP address has changed ($interface $ipaddress/$netmask)");

            $cmd = sprintf "LANG=C sudo ip addr add %s/%i broadcast %s dev %s", $ipaddress, $netmask, $broadcast, $interface;
            eval { $status = pf_run($cmd) };
            if ( $@ || $status ) {
                $status_msg = "Can't delete previous IP address of interface $interface ($ipaddress)";
                $logger->error($status);
                $logger->error("$cmd: $status");
                return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
            }
            elsif ($isDefaultRoute) {
                # Restore gateway
                $models->{system}->setDefaultRoute($ipaddress);
            }
        }

        @result = $self->_listInterfaces('all');
        $models->{network}->cleanupNetworks(\@result);
    }

    # Set type
    $interface_ref->{network} = $new_network;
    $self->setType($interface, $interface_ref, $models);

    return ($STATUS::OK, "Interface $interface successfully edited");
}

=head2 isActive

=cut

sub isActive {
    my ( $self, $interface ) = @_;

    my @interfaces = $self->_listInterfaces($interface);

    my %status = map { ($_->{name} eq 'lo') ? () : ($_->{name} => $_->{is_running}) } @interfaces;

    return \%status;
}

=head2 getType

=cut

sub getType {
    my ( $self, $interface_ref, $models ) = @_;

    my ($status, $type);
    if ($interface_ref->{network}) {
        # Check in networks.conf
        ($status, my $network) = $models->{networks}->read($interface_ref->{network});
        if ( is_success($status) ) {
            $type = $network->{type};
        }
    }
    unless ($type) {
        # Check in pf.conf
        my ($name, $interface);
        $name = $interface_ref->{name};
        $name .= '.' . $interface_ref->{vlan} if ($interface_ref->{vlan});
        ($status, $interface) = $models->{interface}->read($name);

        # if the interface is not defined in pf.conf
        if ( is_error($status) ) {
            $type = 'none';
        }
        # rely on pf.conf's info
        else {
            $type = $interface->{type};
            $type = ($type =~ /management|managed/i) ? 'management' : 'other';
        }
    }

    return $type;
}

=head2 setType

 Update networks.conf and pf.conf

=cut

sub setType {
    my ($self, $interface, $interface_ref, $models) = @_;

    my $type = $interface_ref->{type} || 'none';
    my ($status, $network_ref);

    # we ignore interface type 'Other' (it basically means unsupported in configurator)
    return if ( $type =~ /^other$/i );

    # we delete interface type 'None'
    if ( $type =~ /^none$/i ) {
        $models->{network}->remove($interface_ref->{network}) if ($interface_ref->{network});
        $models->{interface}->remove($interface);
    }
    # otherwise we update pf.conf and networks.conf
    else {
        # Update pf.conf
        $models->{interface}->update_or_create($interface,
                                    $self->_prepare_interface_for_pfconf($interface, $interface_ref, $type));

        # Update networks.conf
        if ( $type =~ /^management$/ ) {
            # management interfaces must not appear in networks.conf
            $models->{network}->remove($interface_ref->{network}) if ($interface_ref->{network});
        }
        else {
            ($status, $network_ref) = $models->{network}->read($interface_ref->{network});
            if (is_error($status)) {
                # Create new network with default values depending on the type
                if ( $type =~ /^vlan-isolation$|^vlan-registration$/i ) {
                    $network_ref =
                      {
                       dhcp_default_lease_time => 30,
                       dhcp_max_lease_time => 30,
                      };
                } else {
                    $network_ref =
                      {
                       dhcp_default_lease_time => 24 * 60 * 60,
                       dhcp_max_lease_time => 24 * 60 * 60,
                      };
                }
            }
            $network_ref->{type} = $type;
            $network_ref->{netmask} = $interface_ref->{'netmask'};
            $network_ref->{gateway} = $interface_ref->{'ipaddress'};
            $network_ref->{dns} = $interface_ref->{'ipaddress'};
            $network_ref->{dhcp_start} = Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(10);
            $network_ref->{dhcp_end} = Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(-10);
            $models->{network}->update_or_create($interface_ref->{network}, $network_ref);
        }
    }
    $models->{network}->rewriteConfig();
    $models->{interface}->rewriteConfig();
}


sub interfaceForDestination {
    my ($self, $destination) = @_;

    my @interfaces = $self->_listInterfaces();

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    foreach my $interface ( @interfaces ) {
        next if ( "$interface" eq "lo" );

        if ($interface->{ipaddress} && $interface->{netmask}) {
            my $network = Net::Netmask->new($interface->{ipaddress}, $interface->{netmask});
            if ($network->match($destination)) {
                return $interface;
            }
        }
    }
}

=head2 _interfaceActive

Check if the requested interface is active or not on the system.

=cut

sub _interfaceActive {
    my ( $self, $interface ) = @_;

    my @result = $self->_listInterfaces($interface);

    return (scalar @result > 0 && $result[0]->{is_running});
}

=head2 _interfaceCurrentlyInUse

=cut

sub _interfaceCurrentlyInUse {
    my ( $self, $interface, $host ) = @_;

    my @result = $self->_listInterfaces($interface);

    if ( scalar @result > 0 && $result[0]->{ipaddress} =~ $host ) {
        return 1;
    }

    return 0;
}

=head2 _interfaceVirtual

=cut

sub _interfaceVirtual {
    my ( $self, $interface ) = @_;

    my ( $physical_device, $vlan_id ) = split( /\./, $interface );
    if ( !$vlan_id ) {
        return;
    }

    return ( $physical_device, $vlan_id );
}

=head2 _listInterfaces

Return a list of all curently installed network interfaces.

=cut

sub _listInterfaces {
    my ($self, $ifname) = @_;

    my @interfaces_list = ();

    $ifname = '' if ($ifname eq 'all');
    my $cmd =
      {
       link => "LANG=C sudo ip -4 -o link show $ifname",
       addr => "LANG=C sudo ip -4 -o addr show %s"
      };
    my ($link, $addr);
    eval { $link = pf_run($cmd->{link}) };
    if ($link) {
        # Parse output of ip command
        while ($link =~ m/^
                          (\d+):\s        # ifindex
                          ([\w\.]+)       # interface name, including the VLAN
                          (?:\@([^:]+))?  # master interface name
                          .+
                          \sstate\s(\S+)  # interface state (UP or DOWN)
                          .+ether\s(\S+)  # netmask address
                         /mgx) {
            my ($ifindex, $name, $master, $state, $hwaddr, $ipaddress, $netmask) = ($1, $2, $3, $4, $5);
            my $interface =
              {
               ifindex => $ifindex,
               name => $name,
               master => $master,
               is_running => ($state eq 'UP'),
               hwaddr => $hwaddr
              };
            eval { $addr = pf_run(sprintf $cmd->{addr}, $name) };
            if ($addr) {
                if ($addr =~ m/\binet (([^\/]+)\/\d+)/) {
                    $interface->{address} = $1,
                    ($ipaddress, $netmask) = ($2, Net::Netmask->new($1)->mask());
                    $interface->{ipaddress} = $ipaddress;
                    $interface->{netmask} = $netmask;
                }
            }
            push(@interfaces_list, $interface);
        }
    }

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

=head2 up

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

    my $cmd = sprintf "LANG=C sudo ip link set %s up", $interface;
    eval { $status = pf_run($cmd) };
    if ( $@ ) {
        $status_msg = "Can't enable interface $interface";
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Check if interface is enabled
    # This check is necessary since the previous call (modification of the flag) does not return error or ok
    if ( !$self->_interfaceActive($interface) ) {
        $status_msg = "Interface $interface has not been enabled. Should check server side logs for details";
        $logger->error("$status_msg | Is the interface correctly plugged in?");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, "Interface $interface successfully enabled");
}

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

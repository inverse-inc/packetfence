package pfappserver::Model::Interface;

=head1 NAME

pfappserver::Model::Interface - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;

use namespace::autoclean;
use Net::Netmask;

use pf::constants;
use pf::config qw(%ConfigDomain);
use pf::error qw(is_error is_success);
use pf::util;
use pf::util::IP;
use pf::log;

extends 'Catalyst::Model';

=head1 METHODS

=head2 create

=cut

sub create {
    my ( $self, $interface ) = @_;
    my $logger = get_logger();

    my ($status, $status_msg);

    # This method does not handle the 'all' interface neither the 'lo' one
    return ($STATUS::FORBIDDEN, "This method does not handle interface $interface")
        if ( ($interface eq 'all') || ($interface eq 'lo') );

    # Check if requested interface exists
    ($status, $status_msg) = $self->exists($interface);
    if ( is_success($status) ) {
        $status_msg = ["Interface VLAN [_1] already exists",$interface];
        return ($STATUS::OK, $status_msg);
    }

    my ($physical_interface, $vlan_id) = split( /\./, $interface );

    # Check if physical interface exists
    ($status, $status_msg) = $self->exists($physical_interface);
    if ( is_error($status) ) {
        $status_msg = ["Physical interface [_1] does not exists so can't create VLAN interface on it",$physical_interface];
        $logger->warn($status_msg);
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Create requested virtual interface
    my $cmd = "sudo vconfig add $physical_interface $vlan_id";
    eval { $status = pf_run($cmd) };
    if ( $@ || !$status ) {
        $status_msg = ["Error in creating interface VLAN [_1]",$interface];
        $logger->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Might want to move this one in the controller... create doesn't invoke up...
    # Enable the newly created virtual interface
    $self->up($interface);

    return ($STATUS::CREATED, ["Interface VLAN [_1] successfully created",$interface]);
}

=head2 delete

=cut

sub delete {
    my ($self, $interface, $host) = @_;

    my $models = $self->{models};
    my $logger = get_logger();

    my ($status, $status_msg);

    # This method does not handle the 'all' interface neither the 'lo' one
    return ($STATUS::FORBIDDEN, ["This method does not handle interface [_1]",$interface])
        if ( ($interface eq 'all') || ($interface eq 'lo') );

    # Retrieve interface definition
    my @results = $self->_listInterfaces($interface);
    my $interface_ref = pop @results;

    # Check if requested interface exists
    if (!defined $interface_ref) {
        $status_msg = ["Interface VLAN [_1] does not exists",$interface];
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Check if requested interface is virtual
    if ( !$self->_interfaceVirtual($interface) ) {
        $status_msg = ["Interface [_1] is not a virtual interface and cannot be deleted",$interface];
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Check if requested interface isn't currently in use
    if ( $self->_interfaceCurrentlyInUse($interface, $host) ) {
        $status_msg = ["Interface VLAN [_1] is currently in use for the configuration",$interface];
        return ($STATUS::FORBIDDEN, $status_msg);
    }

    # Delete requested virtual interface
    my $cmd = "sudo vconfig rem $interface";
    eval { $status = pf_run($cmd) };
    if ( $@ || !$status ) {
        $status_msg = ["Error in deletion of interface VLAN [_1]",$interface];
        $logger->error("Error in deletion of interface VLAN $interface");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Delete corresponding interface entry from pf.conf
    $models->{interface}->remove($interface);
    ($status, $status_msg) = $models->{interface}->commit();
    if(is_error($status)) {
        return ($status, $status_msg);
    }

    # Remove associated network entries
    @results = $self->_listInterfaces('all');
    if ($models->{network}->cleanupNetworks(\@results)) {
        ($status, $status_msg) = $models->{network}->commit();
        if(is_error($status)) {
            return ($status, $status_msg);
        }
    }

    return ($STATUS::OK, ["Interface VLAN [_1] successfully deleted",$interface]);
}

=head2 down

=cut

sub down {
    my ( $self, $interface, $host ) = @_;
    my $logger = get_logger();

    my ($status, $status_msg);

    # This method does not handle the 'all' interface neither the 'lo' one
    return ($STATUS::FORBIDDEN, ["This method does not handle interface [_1]",$interface])
        if ( ($interface eq 'all') || ($interface eq 'lo') );

    # Check if requested interface exists
    ($status, $status_msg) = $self->exists($interface);
    if ( is_error($status) ) {
        $status_msg = ["Interface [_1] does not exists",$interface ];
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Check if requested interface isn't already disabled
    if ( !$self->_interfaceActive($interface) ) {
        $status_msg = ["Interface [_1] is already disabled",$interface];
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Check if requested interface isn't currently in use
    if ( $self->_interfaceCurrentlyInUse($interface, $host) ) {
        $status_msg = ["Interface [_1] is currently in use for the configuration",$interface];
        $logger->warn("Is the interface correctly plugged in?");
        return ($STATUS::FORBIDDEN, $status_msg);
    }

    # Disable interface using "ip"
    my $cmd = sprintf "sudo ip link set %s down", $interface;
    eval { $status = pf_run($cmd) };
    if ( $@ ) {
        $status_msg = ["Can't disable interface [_1] : [_2]",$interface , $status];
        $logger->error("Can't disable interface $interface : $status");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Check if interface is disabled
    # This check is necessary since the previous call (modification of the flag) does not return error or ok
    if ( $self->_interfaceActive($interface) ) {
        $status_msg = ["Interface [_1] has not been disabled. Should check server side logs for details",$interface];
        $logger->error("Interface $interface has not been disabled. Should check server side logs for details");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, ["Interface [_1] successfully disabled",$interface]);
}

=head2 exists

=cut

sub exists {
    my ($self, $interface) = @_;

    my @result = $self->_listInterfaces($interface);

    return ($STATUS::OK, ["Interface [_1] exists",$interface]) if (scalar @result > 0);
    return ($STATUS::NOT_FOUND, ["Interface [_1] does not exists",$interface]);
}

=head2 get

Returns an hashref with:

    $interface => {
        name            => physical int (eth0 even if in a VLAN int)
        ipaddress       => ...
        netmask         => ...
        ipv6_address    => ...
        ipv6_prefix     => ...
        is_running      => true / false value
        network         => network address (ie 192.168.0.0 for a 192.168.0.1 IP)
        hwaddress       => mac address
        type            => enforcement type (see Enforcement model)
    # and optionnally:
        vlan            => vlan tag
        dns             => network dns
    }

Where $interface is physical interface if there's no VLAN interface (eth0)
and phy.vlan (eth0.100) if there's a vlan interface.

=cut

sub get {
    my ( $self, $interface) = @_;
    my $logger = get_logger();
    my $models = $self->{models};

    # Put requested interfaces into an array
    my @interfaces = $self->_listInterfaces($interface);
    my $networks_model = $models->{network};
    my $interface_model = $models->{interface};

    my $result = {};
    my ($status, $return, $config);
    foreach my $interface_ref ( @interfaces ) {
        next if ( $interface_ref->{name} eq "lo" );
        $interface = $interface_ref->{name};
        ($status,$config) = $interface_model->read($interface);
        $config = {} unless is_success($status);
        $result->{"$interface"} = $interface_ref;
        $result->{"$interface"}->{'high_availability'} = defined $config->{type} &&  $config->{type} =~ /high-availability/ ? $TRUE : $FALSE;
        if ((my ($physical_device, $vlan_id) = $self->_interfaceVirtual($interface))) {
          $result->{"$interface"}->{'name'} = $physical_device;
          $result->{"$interface"}->{'vlan'} = $vlan_id;
        }
        $result->{"$interface"}->{'vip'} = $config->{vip};
        if (($result->{"$interface"}->{'network'} = $networks_model->getNetworkAddress($interface_ref->{ipaddress}, $interface_ref->{netmask}))) {
            ($status, $return) = $networks_model->getRoutedNetworks($result->{"$interface"}->{'network'}, $interface_ref->{netmask});
            if (is_success($status)) {
                $result->{"$interface"}->{'networks'} = $return;
            }
            my $network;
            ($status, $network) = $networks_model->read($result->{"$interface"}->{'network'});
            if (is_success($status)) {
                $result->{"$interface"}->{'dns'} = $network->{dns};
                $result->{"$interface"}->{'dhcpd_enabled'} = $network->{dhcpd};
                $result->{"$interface"}->{'nat_enabled'} = $network->{nat_enabled};
                $result->{"$interface"}->{'split_network'} = $network->{split_network};
                $result->{"$interface"}->{'reg_network'} = $network->{reg_network};
                $result->{"$interface"}->{'network_iseditable'} = $TRUE;
            }
        }
        $result->{"$interface"}->{'type'} = $self->getType($interface_ref);
    }
    return $result;
}

=head2 update

=cut

sub update {
    my ($self, $interface, $interface_ref) = @_;
    my $models = $self->{models};
    my $logger = get_logger();

    my ($ipaddress, $netmask, $ipv6_address, $ipv6_prefix, $status, $status_msg);

    # Normalizing IPv6 address if exists
    $interface_ref->{'ipv6_address'} = pf::util::IP::detect($interface_ref->{'ipv6_address'})->normalizedIP if $interface_ref->{'ipv6_address'};

    $interface_ref->{netmask} = '255.255.255.0' unless ($interface_ref->{netmask});
    $ipaddress = $interface_ref->{ipaddress};
    $netmask = $interface_ref->{netmask};
    $ipv6_address = $interface_ref->{'ipv6_address'} if $interface_ref->{'ipv6_address'};
    $ipv6_prefix = $interface_ref->{'ipv6_prefix'} if $interface_ref->{'ipv6_prefix'};

    # This method does not handle the 'all' interface neither the 'lo' one
    return ($STATUS::FORBIDDEN, ["This method does not handle interface [_1]",$interface])
        if ( ($interface eq 'all') || ($interface eq 'lo') );

    # Check if requested interface exists
    ($status, $status_msg) = $self->exists($interface);
    if ( is_error($status) ) {
        $status_msg = ["Interface [_1] does not exists",$interface];
        $logger->warn("Interface $interface does not exists");
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

    my $network_configuration_changed = $FALSE;
    my $gateway = $models->{'system'}->getDefaultGateway();

    # IPv4 handling (live OS change)
    if ( !defined($interface_before->{ipaddress}) || !defined($interface_before->{netmask}) || !defined($ipaddress) || $ipaddress ne $interface_before->{ipaddress} || $netmask ne $interface_before->{netmask} ) {
        $network_configuration_changed = $TRUE;
        my $isDefaultRoute = (defined($interface_before->{ipaddress}) && $gateway eq $interface_before->{ipaddress});

        # Delete previous IP address
        my $cmd;
        if (defined($interface_before->{address}) && $interface_before->{address} ne '') {
            $cmd = sprintf "sudo ip addr del %s dev %s", $interface_before->{address}, $interface_before->{name};
            eval { $status = pf_run($cmd) };
            if ( $@ || $status ) {
                $status_msg = ["Can't delete previous IP address of interface [_1] ([_2])",$interface,$interface_before->{address}];
                $logger->error("Can't delete previous IP address of interface $interface");
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

            $cmd = sprintf "sudo ip addr add %s/%i broadcast %s dev %s", $ipaddress, $netmask, $broadcast, $interface;
            eval { $status = pf_run($cmd) };
            if ( $@ || $status ) {
                $status_msg = ["Can't add new IP address on interface [_1] ([_2])",$interface,$ipaddress];
                $logger->error($status);
                $logger->error("$cmd: $status");
                return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
            }
            elsif ($isDefaultRoute) {
                # Restore gateway
                $models->{'system'}->setDefaultRoute($ipaddress);
            }
        }
    }

    # IPv6 handling (live OS change)
    if ( !defined($interface_before->{ipv6_address}) || !defined($interface_before->{ipv6_prefix}) || !defined($ipv6_address) || $ipv6_address ne $interface_before->{ipv6_address} || $ipv6_prefix ne $interface_before->{ipv6_prefix} ) {
        $network_configuration_changed = $TRUE;

        # Delete previous IP address
        my $cmd;
        if ( defined($interface_before->{ipv6_network}) && $interface_before->{ipv6_network} ne '' ) {
            $cmd = sprintf "sudo ip -6 addr del %s dev %s", $interface_before->{ipv6_network}, $interface_before->{name};
            eval { $status = pf_run($cmd) };
            if ( $@ || $status ) {
                $status_msg = ["Can't delete previous IPv6 address of interface [_1] ([_2])", $interface, $interface_before->{ipv6_network}];
                $logger->error("Can't delete previous IPv6 address of interface $interface");
                $logger->error("$cmd: $status");
                return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
            }
        }

        # Add new IP address and netmask
        if ( $ipv6_address && $ipv6_address ne '' ) {
            my $block = Net::Netmask->new($ipaddress.':'.$netmask);
            my $broadcast = $block->broadcast();
            $netmask = $block->bits();

            $logger->debug("IPv6 address has changed ($interface $ipv6_address/$ipv6_prefix)");

            $cmd = sprintf "sudo ip -6 addr add %s/%i dev %s", $ipv6_address, $ipv6_prefix, $interface;
            eval { $status = pf_run($cmd) };
            if ( $@ || $status ) {
                $status_msg = ["Can't add new IPv6 address on interface [_1] ([_2])", $interface, $ipv6_address];
                $logger->error($status);
                $logger->error("$cmd: $status");
                return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
            }
        }
    }

    # Persistent OS change
    if ( $network_configuration_changed ) {
        if ($ipaddress && $ipaddress ne '') {
            my $interfaces = $self->get('all');
            $models->{'system'}->write_network_persistent($interfaces,$gateway);
        }

        @result = $self->_listInterfaces('all');
        $models->{network}->cleanupNetworks(\@result);
    }

    # Set type
    $interface_ref->{network} = $new_network;
    ($status, $status_msg) = $self->setType($interface, $interface_ref);

    if(is_error($status)) {
        return ($status, $status_msg);
    }

    return ($STATUS::OK, ["Interface [_1] successfully edited",$interface]);
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
    my ( $self, $interface_ref) = @_;
    my $models = $self->{models};

    my ($status, $type);
    if ($interface_ref->{network}) {
        # Check in networks.conf
        ($status, my $network) = $models->{network}->read($interface_ref->{network});
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
            if ($type !~ /radius/i && $type !~ /portal/i) {
                $type = ($type =~ /management|managed/i) ? 'management' : 'other';
            }
        }
    }

    # we rewrite inline to inlinel2 for backwwards compatibility
    $type =~ s/inline$/inlinel2/;
    return $type;
}

=head2 setType

 Update networks.conf and pf.conf

=cut

sub setType {
    my ($self, $interface, $interface_ref) = @_;
    my $logger = get_logger();
    my $models = $self->{models};

    my $type = $interface_ref->{type} || 'none';
    my ($status, $network_ref, $status_msg);

    # we ignore interface type 'Other' (it basically means unsupported in configurator)
    return if ( $type =~ /^other$/i );

    # we delete interface type 'None'
    if ( $type =~ /^none$/i && !$interface_ref->{high_availability} ) {
        $logger->debug("Deleting $interface interface");
        $models->{network}->remove($interface_ref->{network}) if ($interface_ref->{network});
        $models->{interface}->remove($interface);
    }
    # otherwise we update pf.conf and networks.conf
    else {
        # Update pf.conf
        $logger->debug("Updating or creating $interface interface");


        $models->{interface}->update_or_create($interface,
                                    $self->_prepare_interface_for_pfconf($interface, $interface_ref, $type));

        # Update networks.conf
        if ( $type =~ /management|portal|^radius$/ ) {
            # management interfaces must not appear in networks.conf
            $models->{network}->remove($interface_ref->{network}) if ($interface_ref->{network});
        }
        else {
            ($status, $network_ref) = $models->{network}->read($interface_ref->{network});
            my $is_vlan = $type =~ /^vlan-isolation|^vlan-registration|^dns-enforcement/i;
            if (is_error($status)) {
                # Create new network with default values depending on the type
                if ( $is_vlan) {
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
            $network_ref->{gateway} = $interface_ref->{'vip'} || $interface_ref->{'ipaddress'};
            if($is_vlan) {
                $network_ref->{dns} = $interface_ref->{'vip'} || $interface_ref->{'ipaddress'};
            } else {
                $network_ref->{dns} = $interface_ref->{'dns'};
            }
            $network_ref->{dhcpd} = isenabled($interface_ref->{'dhcpd_enabled'}) ? 'enabled' : 'disabled';
            $network_ref->{nat_enabled} = isenabled($interface_ref->{'nat_enabled'}) ? 'enabled' : 'disabled';
            $network_ref->{split_network} = isenabled($interface_ref->{'split_network'}) ? 'enabled' : 'disabled';
            $network_ref->{reg_network} = $interface_ref->{'reg_network'};
            $network_ref->{dhcp_start} = Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(10);
            $network_ref->{dhcp_end} = Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(-10);
            $models->{network}->update_or_create($interface_ref->{network}, $network_ref);
        }
    }
    $logger->debug("Committing changes to $interface interface");
    
    ($status, $status_msg) = $models->{network}->commit();
    if(is_error($status)) {
        return ($status, $status_msg);
    }

    ($status, $status_msg) = $models->{interface}->commit();
    if(is_error($status)) {
        return ($status, $status_msg);
    }
}


sub interfaceForDestination {
    my ($self, $destination) = @_;

    my @interfaces = $self->_listInterfaces('all');

    my $logger = get_logger();
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

    if ( scalar @result > 0
         && $result[0]->{ipaddress}
         && $result[0]->{ipaddress} =~ $host ) {
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
        link        => "sudo ip -4 -o link show $ifname",
        addr        => "sudo ip -4 -o addr show %s",
        ipv6_addr   => "sudo ip -6 -o addr show %s",
      };
    my ($link, $addr, $ipv6_addr);
    eval { $link = pf_run($cmd->{link}) };
    if ($link) {
        # Parse output of ip command
        while ($link =~ m/^
                          (\d+):\s        # ifindex
                          ([\w\.]+)       # interface name, including the VLAN
                          (?:\@([^:]+))?  # master interface name
                          .+
                          \sstate\s(\S+)  # interface state (UP or DOWN or "something else")
                          .+ether\s(\S+)  # netmask address
                         /mgx) {
            my ($ifindex, $name, $master, $state, $hwaddr, $ipaddress, $netmask) = ($1, $2, $3, $4, $5);
            my $interface =
              {
               ifindex => $ifindex,
               name => $name,
               master => $master,
               is_running => ($state ne 'DOWN'),
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
            eval { $ipv6_addr = pf_run(sprintf $cmd->{ipv6_addr}, $name) };
            if ( $ipv6_addr ) {
                if ($ipv6_addr =~ m/\binet6 (([^\/]+)\/(\d+)) scope global/) {
                    $interface->{ipv6_network}  = $1,
                    $interface->{ipv6_address}  = $2,
                    $interface->{ipv6_prefix}   = $3,
                }
                # Normalizing IPv6 address if exists
                $interface->{ipv6_address} = pf::util::IP::detect($interface->{ipv6_address})->normalizedIP if $interface->{ipv6_address};
            }
            # we add it to the interfaces if it's not a virtual interface for the domains
            push(@interfaces_list, $interface) unless exists $ConfigDomain{$interface->{name}};
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
    my $logger = get_logger();

    my $int_config_ref = {
        ip              => $int_model->{'ipaddress'},
        mask            => $int_model->{'netmask'},
        vip             => $int_model->{'vip'},
    };

    $int_config_ref->{'ipv6_address'}   = $int_model->{'ipv6_address'};
    $int_config_ref->{'ipv6_prefix'}    = $int_model->{'ipv6_prefix'};

    # logic to match our awkward relationship between pf.conf's type and
    # enforcement with networks.conf's type
    if ($type =~ /^vlan/i) {
        $int_config_ref->{'type'} = 'internal';
        $int_config_ref->{'enforcement'} = 'vlan';
        if ($type =~ /radius/i) {
            $int_config_ref->{'type'} .= ",radius";
        }
    }
    elsif ($type eq "dns-enforcement") {
        $int_config_ref->{'type'} = 'internal';
        $int_config_ref->{'enforcement'} = 'dns';
    }
    elsif ($type eq "inline") {
        $int_config_ref->{'type'} = 'internal';
        $int_config_ref->{'enforcement'} = "inlinel2";
    }
    elsif ($type =~ /^inlinel\d/i) {
        $int_config_ref->{'type'} = 'internal';
        $int_config_ref->{'enforcement'} = $type;
    }
    elsif ($type =~ /^radius$/i) {
        $int_config_ref->{'type'} = 'radius';
        $int_config_ref->{'enforcement'} = undef;
    }
    elsif ($type =~ /^portal$/i) {
        $int_config_ref->{'type'} = 'portal';
        $int_config_ref->{'enforcement'} = undef;
    }
    else {
        if($int_model->{'high_availability'}) {
            $type .= ",high-availability";
        }
        # here we oversimplify a bit, type supports multivalues but it's
        # out of scope for now
        $int_config_ref->{'type'} = $type;
        $int_config_ref->{'enforcement'} = undef;
    }

    return $int_config_ref;
}

=head2 up

=cut

sub up {
    my ( $self, $interface ) = @_;
    my $logger = get_logger();

    my ($status, $status_msg);

    # This method does not handle the 'all' interface neither the 'lo' one
    return ($STATUS::FORBIDDEN, ["This method does not handle interface [_1]",$interface])
        if ( ($interface eq 'all') || ($interface eq 'lo') );

    # Check if requested interface exists
    ($status, $status_msg) = $self->exists($interface);
    if ( is_error($status) ) {
        $status_msg = ["Interface [_1] does not exists",$interface] ;
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    # Check if requested interface isn't already enabled
    if ( $self->_interfaceActive($interface) ) {
        $status_msg = ["Interface [_1] is already enabled",$interface];
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    my $cmd = sprintf "sudo ip link set %s up", $interface;
    eval { $status = pf_run($cmd) };
    if ( $@ ) {
        $status_msg = ["Can't enable interface [_1]",$interface];
        $logger->error("Can't enable interface $interface");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Check if interface is enabled
    # This check is necessary since the previous call (modification of the flag) does not return error or ok
    if ( !$self->_interfaceActive($interface) ) {
        $status_msg = ["Interface [_1] has not been enabled. Should check server side logs for details",$interface];
        $logger->error(" Is the interface correctly plugged in?");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    return ($STATUS::OK, ["Interface [_1] successfully enabled",$interface]);
}


sub ACCEPT_CONTEXT {
    my ($proto,$c) = @_;
    my $object;
    if(ref($proto)) {
        $object = $proto
    } else {
       $object = $proto->new;
    }
    $object->{models} = {
        'network' => $c->model('Config::Network'),
        'interface' => $c->model('Config::Interface'),
        'system' => $c->model('Config::System'),
    };
    return $object;
}

=head2 getEnforcement

=cut

sub getEnforcement {
    my ($self, $interface_ref) = @_;
    my $models = $self->{models};

    my ($status, $enforcement);
    # Check in pf.conf
    my ($name, $interface);
    $name = $interface_ref->{name};
    $name .= '.' . $interface_ref->{vlan} if ($interface_ref->{vlan});
    ($status, $interface) = $models->{interface}->read($name);

    # if the interface is not defined in pf.conf
    if ( is_error($status) ) {
        $enforcement = 'none';
    }
    # rely on pf.conf's info
    else {
        $enforcement = $interface->{enforcement};
    }

    # we rewrite inline to inlinel2 for backwwards compatibility
    $enforcement =~ s/inline$/inlinel2/;
    return $enforcement;
}

=head2 map_interface_to_networks

Will create a hash that maps which interfaces are tied to which network

=cut

sub map_interface_to_networks {
    my ($self, $interfaces) = @_;
    my $seen_networks = {};
    while(my ($int, $cfg) = each %$interfaces){
        my $network = $cfg->{network};
        next unless($network);
        if(exists $seen_networks->{$network}){
            push @{$seen_networks->{$network}}, $int;
        }
        else {
            $seen_networks->{$network} = [$int];
        }
    }

    return $seen_networks;
}



=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

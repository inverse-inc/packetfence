package pf::dhcp::processor_v6;

=head1 NAME

pf::dhcp::processor_v6

=cut

=head1 DESCRIPTION

Processes DHCPv6 packets

=cut

use strict;
use warnings;

# External libs
use Readonly;

# Internal libs
use pf::constants;
use pf::constants::IP qw($IPV6);
use pf::db();
use pf::ip6log();
use pf::log();
use pf::util::dhcpv6();
use pf::util::IP();
use pf::StatsD::Timer();

use Moose;
extends 'pf::dhcp::processor';


# DHCPv6 message types
Readonly::Hash my %DHCPV6_MESSAGE_TYPES => (
    1   => 'SOLICIT',
    2   => 'ADVERTISE',
    3   => 'REQUEST',
    4   => 'CONFIRM',
    5   => 'RENEW',
    7   => 'REPLY',
    8   => 'RELEASE',
    12  => 'RELAY-FORW',
    13  => 'RELAY-REPL',
);
my %DHCPV6_MESSAGE_TYPES_REVERSED = reverse %DHCPV6_MESSAGE_TYPES;

# DHCPv6 message types <-> processors mapping
# Reference to %DHCPV6_MESSAGE_TYPES
Readonly::Hash my %MESSAGE_TYPE_PROCESSORS => (
    $DHCPV6_MESSAGE_TYPES{'1'}  => 'processDHCPv6Solicit',
    $DHCPV6_MESSAGE_TYPES{'2'}  => 'processDHCPv6Advertise',
    $DHCPV6_MESSAGE_TYPES{'3'}  => 'processDHCPv6Request',
    $DHCPV6_MESSAGE_TYPES{'4'}  => 'processDHCPv6Confirm',
    $DHCPV6_MESSAGE_TYPES{'5'}  => 'processDHCPv6Renew',
    $DHCPV6_MESSAGE_TYPES{'7'}  => 'processDHCPv6Reply',
    $DHCPV6_MESSAGE_TYPES{'8'}  => 'processDHCPv6Release',
);

# DHCPv6 option types
Readonly::Hash my %DHCPV6_OPTION_TYPES => (
    1   => 'CLIENTID',
    2   => 'SERVERID',
    3   => 'IA_NA',
    4   => 'IA_TA',
    5   => 'IAADDR',
    6   => 'REQUESTED_OPTIONS',
    13  => 'STATUS_CODE',
    16  => 'VENDOR_CLASS',
    39  => 'FQDN',
);

# DHCPv6 option processing attributes
# Reference to %DHCPV6_OPTION_TYPES
# Always requires a 'type' (data, container, ip)
# - data: generic data
# - ip: IP address data
# - container: data container (used for recursive options processing)
# Requires 'attributes' to map data wanted
Readonly::Hash my %OPTION_TYPE_ATTRIBUTES => (
    $DHCPV6_OPTION_TYPES{'1'}   => {
        type        => 'data',
        attributes  => {
            addr    => 'client_mac',
        },
    },
    $DHCPV6_OPTION_TYPES{'2'}   => {
        type        => 'data',
        attributes  => {
            addr    => 'server_mac',
        },
    },
    $DHCPV6_OPTION_TYPES{'3'}   => {
        type        => 'container',
        attributes  => {
        },
    },
    $DHCPV6_OPTION_TYPES{'4'}   => {
        type        => 'container',
        attributes  => {
        },
    },
    $DHCPV6_OPTION_TYPES{'5'}   => {
        type        => 'ip',
        attributes  => {
            addr            => 'client_ip',
            valid_lifetime  => 'lease_length',
        },
    },
    $DHCPV6_OPTION_TYPES{'6'}   => {
        type        => 'data',
        attributes  => {
            requested_options   => 'ipv6_requested_options',
        },
    },
    $DHCPV6_OPTION_TYPES{'13'}  => {
        type        => 'data',
        attributes  => {
            status_code     => 'status_code',
            status_message  => 'status_message',
        },
    },
    $DHCPV6_OPTION_TYPES{'16'}   => {
        type        => 'data',
        attributes  => {
            enterprise_number   => 'ipv6_enterprise_number',
            data                => 'ipv6_vendor',
        },
    },
    $DHCPV6_OPTION_TYPES{'39'}   => {
        type        => 'data',
        attributes  => {
            fqdn    => 'client_hostname',
        },
    },
);


=head2 process_packet

Process the packet with the appropriate processor according to the packet message type

=cut

sub process_packet {
    my ( $self, $udp_payload ) = @_;
    my $logger = pf::log::get_logger();

    if ( pf::db::db_check_readonly() ) {
        $logger->trace("The database is in readonly mode skipping processing the database");
        return;
    }

    # The payload is sent in base 64
    $udp_payload = MIME::Base64::decode($udp_payload);
    my $dhcpv6 = pf::util::dhcpv6::decode_dhcpv6($udp_payload);

    # These are relaying packets.
    # In that case we take the inner part
    if ( $dhcpv6->{msg_type} eq $DHCPV6_MESSAGE_TYPES_REVERSED{'RELAY-FORW'} || $dhcpv6->{msg_type} eq $DHCPV6_MESSAGE_TYPES_REVERSED{'RELAY-REPL'} ) {
        $logger->debug("Found relaying packet. Taking inner request/reply from it.");
        $dhcpv6 = $dhcpv6->{options}->[0];
    }

    my $message_type = $DHCPV6_MESSAGE_TYPES{$dhcpv6->{msg_type}};
    my $packet_processor = $MESSAGE_TYPE_PROCESSORS{$message_type} if defined($message_type);

    unless ( defined($message_type) && defined($packet_processor) ) {
        $logger->warn("Got a DHCPv6 packet of type '$dhcpv6->{msg_type}'. Do not process it");
        return;
    }

    $self->$packet_processor($dhcpv6);
}


=head2 _process_options

Process packet options using mapping hashes according to packet message type and options

=cut

sub _process_options {
    my ( $options, $option_attributes, $recursive_attributes ) = @_;
    my $logger = pf::log::get_logger();

    $option_attributes = {} unless ( defined($option_attributes) );
    $recursive_attributes = {} unless ( defined($recursive_attributes) );

    foreach my $option ( @{$options} ) {
        my $option_type = $DHCPV6_OPTION_TYPES{$option->{option_type}};

        # Process defined option types
        if ( defined($option_type) ) {
            $logger->debug("Processing DHCPv6 option of type '$option_type ($option->{option_type})'");

            if ( $OPTION_TYPE_ATTRIBUTES{$option_type}{'type'} eq "container" ) {
                $recursive_attributes->{'type'} = $option_type;
            }

            elsif ( $OPTION_TYPE_ATTRIBUTES{$option_type}{'type'} eq "ip" ) {
                foreach my $key ( keys %{$option} ) {
                    $recursive_attributes->{$OPTION_TYPE_ATTRIBUTES{$option_type}{'attributes'}{$key}} = $option->{$key} if exists $OPTION_TYPE_ATTRIBUTES{$option_type}{'attributes'}{$key};
                }
                push @{$option_attributes->{'ip'}}, $recursive_attributes;
            }

            else {
                foreach my $key ( keys %{$option} ) {
                    $option_attributes->{$OPTION_TYPE_ATTRIBUTES{$option_type}{'attributes'}{$key}} = $option->{$key} if exists $OPTION_TYPE_ATTRIBUTES{$option_type}{'attributes'}{$key};
                }
            }
        }

        # Do not process undefined option types
        else {
            $logger->debug("Got a DHCPv6 option of type '$option->{option_type}'. Do not process it");
        }

        # Recursive traversal
        _process_options($option->{options}, $option_attributes, $recursive_attributes) if exists $option->{options};
        undef $recursive_attributes;
    }

    return $option_attributes;
}


=head2 preProcessIPTasks

Prepare arguments for 'processIPTasks'

=cut

sub preProcessIPTasks {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $self, $iptasks_arguments ) = @_;
    my $logger = pf::log::get_logger();

    $iptasks_arguments->{'ip'} = pf::util::IP::detect($iptasks_arguments->{'ip'})->normalizedIP;
    my $ip  = $iptasks_arguments->{'ip'};
    my $mac = $iptasks_arguments->{'mac'};

    # Sanitize input
    unless ( pf::util::valid_mac($mac) || pf::util::IP::is_ipv6($ip) ) {
        $logger->error("invalid MAC or IP: $mac $ip");
        return;
    }

    # Add IP version to arguments
    $iptasks_arguments->{'ipversion'} = $IPV6;
    
    # Get previous (old) mappings
    $iptasks_arguments->{'oldip'}  = pf::ip6log::_mac2ip_sql($mac);
    $iptasks_arguments->{'oldmac'} = pf::ip6log::_ip2mac_sql($ip);
}


=head2 checkForParking

=cut

sub checkForParking {
    my ( $self ) = @_;
    my $logger = pf::log::get_logger();

    $logger->debug("Parking not implemented for IPv6");
}


=head2 processDHCPv6Solicit

DHCPv6 message-type 1 (Clients)

As per RFC 3315:
A client sends a Solicit message to locate servers.

=cut

sub processDHCPv6Solicit {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $self, $dhcpv6 ) = @_;
    my $logger = pf::log::get_logger();

    my $message_type = $DHCPV6_MESSAGE_TYPES{$dhcpv6->{msg_type}};
    $logger->debug("Processing DHCPv6 packet of type '$message_type ($dhcpv6->{msg_type})'");

    my $attributes = _process_options($dhcpv6->{options});

    # Fingerbank integration
    $self->processFingerbank($attributes);
}


=head2 processDHCPv6Advertise

DHCPv6 message-type 2 (Servers)

As per RFC 3315:
A server sends an Advertise message to indicate that it is available for DHCP service, in response to a Solicit message received from 
a client.

=cut

sub processDHCPv6Advertise {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $self, $dhcpv6 ) = @_;
    my $logger = pf::log::get_logger();

    my $message_type = $DHCPV6_MESSAGE_TYPES{$dhcpv6->{msg_type}};
    $logger->debug("Processing DHCPv6 packet of type '$message_type ($dhcpv6->{msg_type})'");

    my $attributes = _process_options($dhcpv6->{options});
}


=head2 processDHCPv6Request

DHCPv6 message-type 3 (Clients)

As per RFC 3315:
A client sends a Request message to request configuration parameters, including IP 
addresses, from a specific server.

=cut

sub processDHCPv6Request {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $self, $dhcpv6 ) = @_;
    my $logger = pf::log::get_logger();

    my $message_type = $DHCPV6_MESSAGE_TYPES{$dhcpv6->{msg_type}};
    $logger->debug("Processing DHCPv6 packet of type '$message_type ($dhcpv6->{msg_type})'");

    my $attributes = _process_options($dhcpv6->{options});
}


=head2 processDHCPv6Confirm

DHCPv6 message-type 4 (Clients)

As per RFC 3315:
A client sends a Confirm message to any available server to determine whether the addresses it was assigned 
are still appropriate to the link to which the client is connected.

=cut

sub processDHCPv6Confirm {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $self, $dhcpv6 ) = @_;
    my $logger = pf::log::get_logger();

    my $message_type = $DHCPV6_MESSAGE_TYPES{$dhcpv6->{msg_type}};
    $logger->debug("Processing DHCPv6 packet of type '$message_type ($dhcpv6->{msg_type})'");

    my $attributes = _process_options($dhcpv6->{options});
}


=head2 processDHCPv6Renew

DHCPv6 message-type 5 (Clients)

As per RFC 3315:
A client sends a Renew message to the server that originally provided the client's addresses and configuration parameters to extend 
the lifetimes on the addresses assigned to the client and to update other configuration parameters.

=cut

sub processDHCPv6Renew {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $self, $dhcpv6 ) = @_;
    my $logger = pf::log::get_logger();

    my $message_type = $DHCPV6_MESSAGE_TYPES{$dhcpv6->{msg_type}};
    $logger->debug("Processing DHCPv6 packet of type '$message_type ($dhcpv6->{msg_type})'");

    my $attributes = _process_options($dhcpv6->{options});
}

=head2 processDHCPv6Reply

DHCPv6 message-type 7 (Servers)

As per RFC 3315:
A server sends a Reply message containing assigned addresses and configuration parameters in response to a Solicit, Request, Renew, 
Rebind message received from a client.  A server sends a Reply message containing configuration parameters in response to an 
Information-request message.  A server sends a Reply message in response to a Confirm message confirming or denying that the addresses 
assigned to the client are appropriate to the link to which the client is connected.  A server sends a Reply message to acknowledge 
receipt of a Release or Decline message.

=cut

sub processDHCPv6Reply {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $self, $dhcpv6 ) = @_;
    my $logger = pf::log::get_logger();

    my $message_type = $DHCPV6_MESSAGE_TYPES{$dhcpv6->{msg_type}};
    $logger->debug("Processing DHCPv6 packet of type '$message_type ($dhcpv6->{msg_type})'");

    my $attributes = _process_options($dhcpv6->{options});

    # Handling IP tasks
    if ( $attributes->{'ip'} && $attributes->{'client_mac'} ) {
        foreach my $ip ( @{$attributes->{'ip'}} ) {
            $self->processIPTasks( (client_mac => $attributes->{'client_mac'}, client_ip => $ip->{'client_ip'}, lease_length => $ip->{'lease_length'}, ip_type => $ip->{'type'}) );
        }
        
    }
}


=head2 processDHCPv6Release

DHCPv6 message-type 8 (Clients)

As per RFC 3315:
A client sends a Release message to the server that assigned addresses to the client to 
indicate that the client will no longer use one or more of the assigned addresses.

=cut

sub processDHCPv6Release {
    my $timer = pf::StatsD::Timer->new({level => 6});
    my ( $self, $dhcpv6 ) = @_;
    my $logger = pf::log::get_logger();

    my $message_type = $DHCPV6_MESSAGE_TYPES{$dhcpv6->{msg_type}};
    $logger->debug("Processing DHCPv6 packet of type '$message_type ($dhcpv6->{msg_type})'");

    my $attributes = _process_options($dhcpv6->{options});
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

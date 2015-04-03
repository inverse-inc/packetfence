package pfconfig::namespaces::interfaces;

=head1 NAME

pfconfig::namespaces::interfaces

=cut

=head1 DESCRIPTION

pfconfig::namespaces::interfaces

=cut

use strict;
use warnings;

use pfconfig::log;
use pf::constants::config qw(%NET_INLINE_TYPES);
use pfconfig::namespaces::config::Pf;
use pfconfig::util qw(is_type_inline);
use Net::Netmask;
use Net::Interface;
use Socket;
use pf::util;

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self, $host_id) = @_;
    $self->{_interfaces} = {
        listen_ints             => [],
        dhcplistener_ints       => [],
        ha_ints                 => [],
        internal_nets           => [],
        inline_enforcement_nets => [],
        vlan_enforcement_nets   => [],
        monitor_int             => '',
        management_network      => '',
    };
    $self->{child_resources} = [
        'interfaces::listen_ints',             'interfaces::dhcplistener_ints',
        'interfaces::ha_ints',                 'interfaces::internal_nets',
        'interfaces::inline_enforcement_nets', 'interfaces::vlan_enforcement_nets',
        'interfaces::monitor_int',             'interfaces::management_network',
    ];
    if($host_id){
        @{$self->{child_resources}} = map { "$_($host_id)" } @{$self->{child_resources}}; 
    }
    $self->{config_resource} = pfconfig::namespaces::config::Pf->new( $self->{cache}, $host_id );
    #$self->{cluster_enabled} = pfconfig::namespaces::resource::cluster_enabled->new( $self->{cache} )->build();
    require pf::cluster;
    $self->{cluster_enabled} = $pf::cluster::cluster_enabled;
}

sub build {
    my ($self) = @_;
    my $logger = pfconfig::log::get_logger;

    my $config = $self->{config_resource};
    $self->{config} = $config->build();
    my %Config = %{ $self->{config} };

    foreach my $interface ( $config->GroupMembers("interface") ) {
        my $int_obj;
        my $int = $interface;
        $int =~ s/interface //;

        my $ip   = $Config{$interface}{'ip'};
        my $mask = $Config{$interface}{'mask'};
        my $type = $Config{$interface}{'type'};

        if ( defined($ip) && defined($mask) ) {
            $ip =~ s/ //g;
            $mask =~ s/ //g;
            $int_obj = new Net::Netmask( $ip, $mask );
            $int_obj->tag( "ip",  $ip );
            $int_obj->tag( "int", $int );
        }

        if ( !defined($type) ) {
            $logger->warn("$int: interface type not defined");

            # setting type to empty to avoid warnings on split below
            $type = '';
        }

        die "Missing mandatory element ip or netmask on interface $int"
            if ( $type =~ /internal|managed|management/ && !defined($int_obj) );

        foreach my $type ( split( /\s*,\s*/, $type ) ) {
            if ( $type eq 'internal' ) {
                $int_obj->tag( "vip", $self->_fetch_virtual_ip( $int, $interface ) );
                push @{ $self->{_interfaces}->{internal_nets} }, $int_obj;
                if ( $Config{$interface}{'enforcement'} eq $pf::constants::config::IF_ENFORCEMENT_VLAN ) {
                    push @{ $self->{_interfaces}->{vlan_enforcement_nets} }, $int_obj;
                }
                elsif ( is_type_inline( $Config{$interface}{'enforcement'} ) ) {
                    push @{ $self->{_interfaces}->{inline_enforcement_nets} }, $int_obj;
                }
                if ( $int =~ m/(\w+):\d+/ ) {
                    $int = $1;
                }
                push @{ $self->{_interfaces}->{listen_ints} }, $int if ( $int !~ /:\d+$/ );
            }
            elsif ( $type eq 'managed' || $type eq 'management' ) {
                $int_obj->tag( "vip", $self->_fetch_virtual_ip( $int, $interface ) );
                $self->{_interfaces}->{management_network} = $int_obj;

                # adding management to dhcp listeners by default (if it's not already there)
                push @{ $self->{_interfaces}->{dhcplistener_ints} }, $int
                    if ( not scalar grep( { $_ eq $int } @{ $self->{_interfaces}->{dhcplistener_ints} } ) );

            }
            elsif ( $type eq 'monitor' ) {
                $self->{_interfaces}->{monitor_int} = $int;
            }
            elsif ( $type =~ /^dhcp-?listener$/i ) {
                push @{ $self->{_interfaces}->{dhcplistener_ints} }, $int;
            }
            elsif ( $type eq 'high-availability' ) {
                push @{ $self->{_interfaces}->{ha_ints} }, $int;
            }
        }
    }

    return $self->{_interfaces};
}

sub _fetch_virtual_ip {
    my ( $self, $interface, $config_section ) = @_;

    my %Config = %{ $self->{config} };
    my $cluster_enabled = $self->{cluster_enabled};

    # [interface $int].vip= ... always wins
    return $Config{$config_section}{'vip'} if defined( $Config{$config_section}{'vip'} );

    return if ($cluster_enabled);

    my $if = Net::Interface->new($interface);
    return if ( !defined($if) );

    # these array are ordered the same way, that's why we can assume the following
    my @masks     = $if->netmask( AF_INET() );
    my @addresses = $if->address( AF_INET() );

    for my $i ( 0 .. $#masks ) {
        return inet_ntoa( $addresses[$i] ) if ( inet_ntoa( $masks[$i] ) eq '255.255.255.255' );
    }
    return;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:


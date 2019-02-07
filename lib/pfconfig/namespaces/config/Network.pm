package pfconfig::namespaces::config::Network;

=head1 NAME

pfconfig::namespaces::config::Network

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Network

This module creates the configuration hash associated to networks.conf

=cut

use strict;
use warnings;

use pf::log;
use pfconfig::namespaces::config;
use pf::constants;
use pf::file_paths qw($network_config_file);
use pf::constants::config;
use pfconfig::util qw(is_type_inline);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self, $host_id) = @_;
    $self->{cluster_name} = ($host_id ? $self->{cache}->get_cache("resource::clusters_hostname_map")->{$host_id} : undef) // "DEFAULT";

    $self->{file}            = $network_config_file;
    $self->{child_resources} = [
        'interfaces',
        'resource::network_config'
    ];
    
    $self->{cluster_config}  = $self->{cluster_name} ? $self->{cache}->get_cache("config::Cluster(".$self->{cluster_name}.")") : {};
}

sub build_child {
    my ($self) = @_;

    my $logger = get_logger;

    my %ConfigNetworks = %{ $self->{cfg} };

    my ($config) = @_;
    $self->cleanup_whitespaces( \%ConfigNetworks );

    my %ConfigCluster  = %{ $self->{cluster_config} };

    # for cluster overlaying
    if(defined($self->{cluster_name}) && exists($ConfigCluster{CLUSTER})){
        $logger->debug("Doing the network overlaying for cluster");
        while(my ($key, $config) = (each %{$ConfigCluster{CLUSTER}})){
            if($key =~ /^network ([0-9.]+)/){
                my $net = $1;
                $logger->debug("Reconfiguring network $net with cluster information");
                while(my ($param, $value) = each(%$config)) {
                    $ConfigNetworks{$net}{$param} = $value;
                }
            }
        }
    }
    elsif(defined($self->{host_id})){
        $logger->warn("A host was defined for the config::Pf namespace but no cluster configuration was found. This is not a big issue but it's worth noting.")
    }

    return \%ConfigNetworks;

}

=head2 is_network_type_vlan_reg

Returns true if given network is of type vlan-registration and false otherwise.

=cut

sub is_network_type_vlan_reg {
    my ($type) = @_;

    my $result = get_network_type($type);
    if ( defined($result) && $result eq $pf::constants::config::NET_TYPE_VLAN_REG ) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}

=head2 is_network_type_dns_enforcement

Returns true if given network is of type dns-enforcement and false otherwise.

=cut

sub is_network_type_dns_enforcement {
    my ($type) = @_;

    my $result = get_network_type($type);
    if ( defined($result) && $result eq $pf::constants::config::NET_TYPE_DNS_ENFORCEMENT ) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}

=head2 is_network_type_vlan_isol

Returns true if given network is of type vlan-isolation and false otherwise.

=cut

sub is_network_type_vlan_isol {
    my ($type) = @_;

    my $result = get_network_type($type);
    if ( defined($result) && $result eq $pf::constants::config::NET_TYPE_VLAN_ISOL ) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}

=head2 is_network_type_inline

Returns true if given network is of type inline and false otherwise.

=cut

sub is_network_type_inline {
    my ($type) = @_;

    my $result = get_network_type($type);
    if ( defined($result) && $result eq $pf::constants::config::NET_TYPE_INLINE ) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}

sub get_network_type {
    my ($type) = @_;

    if ( !defined($type) ) {

        # not defined
        return;
    }
    elsif ( $type =~ /^$pf::constants::config::NET_TYPE_VLAN_REG$/i ) {

        # vlan-registration
        return $pf::constants::config::NET_TYPE_VLAN_REG;

    }
    elsif ( $type =~ /^$pf::constants::config::NET_TYPE_VLAN_ISOL$/i ) {

        # vlan-isolation
        return $pf::constants::config::NET_TYPE_VLAN_ISOL;

    }
    elsif ( $type =~ /^$pf::constants::config::NET_TYPE_DNS_ENFORCEMENT$/i ) {

        # dns-enforcement
        return $pf::constants::config::NET_TYPE_DNS_ENFORCEMENT;

    }
    elsif ( is_type_inline($type) ) {

        # inline
        return $pf::constants::config::NET_TYPE_INLINE;

    }
    elsif ( $type =~ /^registration$/i ) {

        # deprecated registration
        return $pf::constants::config::NET_TYPE_VLAN_REG;

    }
    elsif ( $type =~ /^isolation$/i ) {

        # deprecated isolation
        return $pf::constants::config::NET_TYPE_VLAN_ISOL;
    }

    return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:


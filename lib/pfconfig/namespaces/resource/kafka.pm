package pfconfig::namespaces::resource::kafka;

=head1 NAME

pfconfig::namespaces::resource::kafka

=head1 DESCRIPTION

pfconfig::namespaces::resource::kafka

Wraps config::Kafka and resolves %mgmtip% tags with the actual management IP address.

=cut

use strict;
use warnings;

use pf::log;

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self, $host_id) = @_;
    $self->{_kafka_config} = $self->{cache}->get_cache('config::Kafka');
    $host_id //= "";
    $self->{_management_network} = $self->{cache}->get_cache("interfaces::management_network($host_id)");
}

sub build {
    my ($self) = @_;

    # Deep copy the config to avoid modifying the cached original
    my %kafka_config = %{ $self->{_kafka_config} };

    # Get management IP for tag replacement
    my $mgmt_ip = $self->_get_management_ip();

    # Replace %mgmtip% tags in iptables section
    if (exists $kafka_config{iptables} && defined $mgmt_ip) {
        my $iptables = $kafka_config{iptables};
        for my $f (qw(cluster_ips clients)) {
            next if !exists $iptables->{$f};
            next if ref($iptables->{$f}) ne 'ARRAY';

            # Replace %mgmtip% in each array element
            $iptables->{$f} = [
                map { my $v = $_; $v =~ s/%mgmtip%/$mgmt_ip/g; $v }
                @{$iptables->{$f}}
            ];
        }
    }

    return \%kafka_config;
}

sub _get_management_ip {
    my ($self) = @_;
    my $logger = get_logger();

    my $management_network = $self->{_management_network};
    if (!$management_network) {
        $logger->warn("resource::kafka - Management network not configured, %mgmtip% tags will not be replaced");
        return undef;
    }

    # Prefer VIP for cluster setups, otherwise use regular IP
    my $mgmt_ip = $management_network->tag('vip') // $management_network->tag('ip');

    if (!$mgmt_ip) {
        $logger->warn("resource::kafka - Management network IP not found, %mgmtip% tags will not be replaced");
        return undef;
    }

    return $mgmt_ip;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2025 Inverse inc.

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

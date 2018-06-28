package pfconfig::namespaces::config::Stats;

=head1 NAME

pfconfig::namespaces::config::Stats

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Stats

This module creates the configuration hash associated to stats.conf

=cut


use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::log;
use pf::file_paths qw($stats_config_file);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $stats_config_file;
    
    $self->{network_config} = $self->{cache}->get_cache('resource::network_config');
}

sub build_child {
    my ($self) = @_;
    my %tmp_cfg = %{$self->{cfg}};
    foreach my $key ( keys %tmp_cfg){
        $self->cleanup_whitespaces(\%tmp_cfg);
    }

    foreach my $network (keys $self->{network_config}) {
        my $dev = $self->{network_config}{$network}{'interface'}{'int'};
        next if !defined $dev;
        $tmp_cfg{"metric 'total dhcp leases remaining on $network' past day"} = {
            'type' => 'api',
            'statsd_type' => 'gauge',
            'statsd_ns' => 'source.packetfence.dhcp_leases_'.$network.'_day',
            'api_method' => 'GET',
            'api_path' => "/api/v1/dhcp/stats/$dev/$network",
            'api_compile' => '$[0].free',
            'interval' => '24s',
        };
        $tmp_cfg{"metric 'total dhcp leases remaining on $network' past week"} = {
            'type' => 'api',
            'statsd_type' => 'gauge',
            'statsd_ns' => 'source.packetfence.dhcp_leases_'.$network.'_week',
            'api_method' => 'GET',
            'api_path' => "/api/v1/dhcp/stats/$dev/$network",
            'api_compile' => '$[0].free',
            'interval' => '168s',
        };
        $tmp_cfg{"metric 'total dhcp leases remaining on $network' past month"} = {
            'type' => 'api',
            'statsd_type' => 'gauge',
            'statsd_ns' => 'source.packetfence.dhcp_leases_'.$network.'_month',
            'api_method' => 'GET',
            'api_path' => "/api/v1/dhcp/stats/$dev/$network",
            'api_compile' => '$[0].free',
            'interval' => '720s',
        };
        $tmp_cfg{"metric 'total dhcp leases remaining on $network' past year"} = {
            'type' => 'api',
            'statsd_type' => 'gauge',
            'statsd_ns' => 'source.packetfence.dhcp_leases_'.$network.'_year',
            'api_method' => 'GET',
            'api_path' => "/api/v1/dhcp/stats/$dev/$network",
            'api_compile' => '$[0].free',
            'interval' => '8760s',
        };
    }

    return \%tmp_cfg;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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


package pf::services::manager::pfdns_connector;

=head1 NAME

pf::services::manager::pfdns_connector

=cut

=head1 DESCRIPTION

pf::services::manager::pfdns_connector

=cut

use strict;
use warnings;
use Template;

use pf::file_paths qw(
    $conf_dir
    $generated_conf_dir
);
use pf::config;
use pf::util;
use Moo;

extends 'pf::services::manager';
with 'pf::services::manager::roles::env_golang_service';

has '+name' => ( default => sub { 'pfdns-connector' } );

tie our %connectors_config, 'pfconfig::cached_hash', 'resource::connectors_config';

=head2 generateConfig

Generate the configuration file

=cut

sub generateConfig {
    my ($self,$quick) = @_;
    my $tt = Template->new(ABSOLUTE => 1);
    my %tags;

    $tags{'connectors'} = \%connectors_config;
    if (isenabled($ENV{PF_SAAS})) {
        my @ips;
        foreach my $fqdn ('pfconnector-0.pfconnector-headless','pfconnector-1.pfconnector-headless') {
            my $resolved_ips = pf::util::resolve($fqdn);
            if (defined($resolved_ips)) {
	        foreach my $ip (@{$resolved_ips}) {
                    push(@ips, $ip);
                }
            }
        }
        if (@ips) {
            $tags{'PFCONNECTOR_SERVICE_HOST'} = \@ips;
        } else {
            $tags{'PFCONNECTOR_SERVICE_HOST'} = '{$K8S_DNS_SERVER}';
        }
    } else {
        $tags{'PFCONNECTOR_SERVICE_HOST'} = '100.64.0.1';
    }
    $tags{'PFCONNECTOR_PORT'} = "53";
    if (isenabled($ENV{PF_SAAS})) {
        $tags{'MAIN_DNS'} = '{$K8S_DNS_SERVER}';
    } else {
        $tags{'MAIN_DNS'} = <<"EOT";
/etc/resolv.conf {
        prefer_udp
    }
EOT
    }
    $tt->process("$conf_dir/pfdns-connector.conf", \%tags, "$generated_conf_dir/pfdns-connector.conf") or die $tt->error();
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

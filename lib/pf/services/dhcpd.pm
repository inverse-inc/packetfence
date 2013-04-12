package pf::services::dhcpd;

=head1 NAME

pf::services::dhcpd - helper configuration module for dhcpd

=head1 DESCRIPTION

This module contains some functions that generates dhcpd configuration
according to what PacketFence needs to accomplish.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files: F<conf/dhcpd.conf>.

Generates the following configuration files: F<var/conf/dhcpd.conf> and F<var/dhcpd/>.

=cut

use strict;
use warnings;
use Log::Log4perl;
use POSIX;
use Readonly;
use Net::Netmask;

use pf::config;
use pf::util;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        generate_dhcpd_conf
    );
}

=head1 SUBROUTINES

=over

=item generate_dhcpd_conf

Generate the proper dhcpd configuration for PacketFence's operation

=cut
sub generate_dhcpd_conf {
    my $logger = Log::Log4perl::get_logger('pf::services::dhcpd');

    my %tags;
    my %direct_subnets;
    $tags{'template'} = "$conf_dir/dhcpd.conf";
    $tags{'networks'} = '';

    foreach my $interface ( @listen_ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        my $net = new Net::Netmask($cfg->{'ip'}, $cfg->{'mask'});
        my ($base,$mask) = ($net->base(), $net->mask());
        $direct_subnets{"subnet $base netmask $mask"} = $TRUE;
    }

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};

        if ( $net{'dhcpd'} eq 'enabled' ) {
            my $domain = sprintf("%s.%s", $net{'type'}, $Config{general}{domain});
            delete $direct_subnets{"subnet $network netmask $net{'netmask'}"};

            %net = _assign_defaults(%net);

            $tags{'networks'} .= <<"EOT";
subnet $network netmask $net{'netmask'} {
  option routers $net{'gateway'};
  option subnet-mask $net{'netmask'};
  option domain-name "$domain";
  option domain-name-servers $net{'dns'};
  range $net{'dhcp_start'} $net{'dhcp_end'};
  default-lease-time $net{'dhcp_default_lease_time'};
  max-lease-time $net{'dhcp_max_lease_time'};
}

EOT
        }
    }

    # Generate empty subnets for every interface where we want dhcpd to
    # listen but no direct DHCP service is provided
    foreach my $network ( keys %direct_subnets ) {
            $tags{'networks'} .= <<"EOT";
$network {
}

EOT
    }

    parse_template( \%tags, "$conf_dir/dhcpd.conf", "$generated_conf_dir/dhcpd.conf" );
    return 1;
}

=item assign_defaults

Will replace all undef with default values.

=cut
# TODO should handle also dhcp_start and dhcp_end but it's more complex
#      requires network / netmask extrapolation
sub _assign_defaults {
    my (%net) = @_;

    $net{'dhcp_default_lease_time'} = 300 if (!defined($net{'dhcp_default_lease_time'}));
    $net{'dhcp_max_lease_time'} = 600 if (!defined($net{'dhcp_max_lease_time'}));

    return %net;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

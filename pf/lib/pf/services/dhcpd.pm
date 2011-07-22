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
    $tags{'template'} = "$conf_dir/dhcpd.conf";
    $tags{'networks'} = '';

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};

        if ( $net{'dhcpd'} eq 'enabled' ) {

            $tags{'networks'} .= <<"EOT";
subnet $network netmask $net{'netmask'} {
  option routers $net{'gateway'};
  option subnet-mask $net{'netmask'};
  option domain-name "$net{'domain-name'}";
  option domain-name-servers $net{'dns'};
  range $net{'dhcp_start'} $net{'dhcp_end'};
  default-lease-time $net{'dhcp_default_lease_time'};
  max-lease-time $net{'dhcp_max_lease_time'};
}

EOT
        }
    }

    parse_template( \%tags, "$conf_dir/dhcpd.conf", "$generated_conf_dir/dhcpd.conf" );
    return 1;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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

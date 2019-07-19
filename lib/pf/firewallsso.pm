package pf::firewallsso;

=head1 NAME

pf::firewallsso

=cut

=head1 DESCRIPTION

Sends firewall SSO request to pfsso engine

=cut

use strict;
use warnings;

use pf::api::jsonrpcclient;
use pf::config qw(
    %ConfigFirewallSSO
);
use pf::constants qw(
    $TRUE
);
use pf::constants::api;
use pf::constants::firewallsso qw($UNKNOWN);
use pf::log;
use pf::node();
use pf::util();


=head1 SUBROUTINES

=over


=item do_sso

=cut

sub do_sso {
    my ( %postdata ) = @_;
    my $logger = pf::log::get_logger();

    unless ( scalar keys %ConfigFirewallSSO ) {
        $logger->debug("Trying to do firewall SSO without any firewall SSO configured. Exiting");
        return;
    }

    my $mac = pf::util::clean_mac($postdata{mac});
    my $node = pf::node::node_attributes($mac);

    $logger->info("Sending a firewall SSO '$postdata{method}' request for MAC '$mac' and IP '$postdata{ip}'");

    my $username = $node->{pid};
    my ($stripped_username, $realm) = pf::util::strip_username($username);

    pf::api::unifiedapiclient->management_client->call("POST", "/api/v1/firewall_sso/".lc($postdata{method}), {
        ip                => $postdata{ip},
        mac               => $mac,
        # All values must be string for pfsso
        timeout           => ($postdata{timeout} // "" ) ."",
        role              => $node->{category},
        username          => $username,
        stripped_username => $stripped_username,
        realm             => $realm,
        status            => $node->{status},
        device_version    => $node->{device_version} || $UNKNOWN,
        device_class      => $node->{device_class} || $UNKNOWN,
        device_type       => $node->{device_type} || $UNKNOWN,
        computername      => $node->{computername} || $UNKNOWN,
    });

    return $TRUE;
}


=back

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


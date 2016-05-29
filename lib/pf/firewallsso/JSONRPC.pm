package pf::firewallsso::JSONRPC;

=head1 NAME

pf::firewallsso::JSONRPC

=head1 SYNOPSIS

The pf::firewallsso::JSONRPC module implements an object oriented interface
to update your firewall using generic JSON-RPC calls.

=cut


use strict;
use warnings;

use base ('pf::firewallsso');

use POSIX;

use pf::config qw(%ConfigFirewallSSO);
sub description { 'JSON-RPC Server' }
use pf::node qw(node_view);
use pf::log;
use pf::api::jsonrpcclient;

=head1 METHODS

=head2 action

Perform a JSON-RPC request based on the registration status of the node and its role.

=cut

sub action {
    my ($self,$firewall_conf,$method,$mac,$ip,$timeout) = @_;
    my $logger = get_logger();

    my $apiclient = pf::api::jsonrpcclient->new(
        username => $ConfigFirewallSSO{$firewall_conf}->{'username'},
        password => $ConfigFirewallSSO{$firewall_conf}->{'password'},
        proto => 'https',
        host => $firewall_conf,
        port => $ConfigFirewallSSO{$firewall_conf}->{'port'}
        );

    my $node_info = node_view($mac);
    my $username = $node_info->{'pid'};
    my @categories = @{$self->{categories}};

    if (
        defined($node_info) &&
        (ref($node_info) eq 'HASH') &&
        $node_info->{'status'} eq $pf::node::STATUS_REGISTERED &&
        (grep $_ eq $node_info->{'category'}, @categories)
    ){
        # Create a request
        my @result = $apiclient->call(
            $method,
            $username,
            $mac,
            $ip,
            $node_info->{'category'},
            $timeout
            );

        # Check the outcome of the response
        if ($result[0] eq "OK") {
            $logger->info("Username $username with node $mac was set to $method using JSON-RPC");
        }
        else {
            $logger->warn("Username $username with node $mac could not be set to $method using JSON-RPC: $result[0]");
        }
    }
    else {
        $logger->warn("Not sending user $username to firewall ($mac/$ip/$timeout) because node is not registered or has unknown role");
    }
    return 0;
}
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

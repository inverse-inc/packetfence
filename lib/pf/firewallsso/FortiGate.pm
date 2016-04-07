package pf::firewallsso::FortiGate;

=head1 NAME

pf::firewallsso::FortiGate

=head1 SYNOPSIS

The pf::firewallsso::FortiGate module implements an object oriented interface
to update the FortiGate user table.

=cut


use strict;
use warnings;

use base ('pf::firewallsso');

use POSIX;
use pf::log;

use pf::config qw(%ConfigFirewallSSO);
sub description { 'FortiGate Firewall' }
use pf::util::radius qw(perform_rsso);
use pf::node qw(node_view);
use pf::accounting qw(node_accounting_current_sessionid);

=head1 METHODS

=head2 action

Perform a radius accounting request based on the registered status of the node and his role.

=cut

sub action {
    my ($self,$firewall_conf,$method,$mac,$ip,$timeout) = @_;
    my $logger = $self->logger;

    my $node_info = node_view($mac);

    my @categories = @{$self->{categories}};
    if (
        defined($node_info) &&
        (ref($node_info) eq 'HASH') &&
        $node_info->{'status'} eq $pf::node::STATUS_REGISTERED &&
        (grep $_ eq $node_info->{'category'}, @categories)
    ){
        my $username = $node_info->{'pid'};
        $username = $node_info->{'last_dot1x_username'} if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x');
        return 0 if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x' && $node_info->{'last_dot1x_username'} eq '');
        my $acctsessionid = node_accounting_current_sessionid($mac);
        my $connection_info = {
          nas_ip => $firewall_conf,
          nas_port => $ConfigFirewallSSO{$firewall_conf}->{'port'},
          secret => $ConfigFirewallSSO{$firewall_conf}->{'password'},
        };

        my $attributes = {
            'Acct-Status-Type' => $method,
            'User-Name' => $username,
            'Class' => $node_info->{'category'},
            'Called-Station-Id' => '00:11:22:33:44:55',
            'Framed-IP-Address' => $ip,
            'Calling-Station-Id' => $mac,
        };

        my $vsa = [];

        perform_rsso($connection_info,$attributes,$vsa);
        $logger->info("Node $mac registered and allowed to pass the Firewall");
        return 1;
    } elsif($method eq "Stop") {
        my $username = $node_info->{'pid'};
        $username = $node_info->{'last_dot1x_username'} if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x');
        return 0 if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x' && $node_info->{'last_dot1x_username'} eq '');
        my $acctsessionid = node_accounting_current_sessionid($mac);
        my $connection_info = {
          nas_ip => $firewall_conf,
          nas_port => $ConfigFirewallSSO{$firewall_conf}->{'port'},
          secret => $ConfigFirewallSSO{$firewall_conf}->{'password'},
        };

        my $attributes = {
            'Acct-Session-Id' =>  "acct_pf-$mac",
            'Acct-Status-Type' => 'Stop',
            'User-Name' => $username,
            'Class' => $node_info->{'category'},
            'Called-Station-Id' => '00:11:22:33:44:55',
            'Framed-IP-Address' => $ip,
            'Calling-Station-Id' => $mac,
        };

        my $vsa = [];

        perform_rsso($connection_info,$attributes,$vsa);
        $logger->info("Node $mac unregistered and disallowed to pass the Firewall");
        return 1;
    }
}

=head2 logger

Return the current logger for the switch

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
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

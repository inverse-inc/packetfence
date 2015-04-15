package pf::firewallsso::Checkpoint;

=head1 NAME

pf::firewallsso::Checkpoint

=head1 SYNOPSIS

The pf::firewallsso::Checkpoint module implements an object oriented interface
to update the Checkpoint user table.

=cut

use strict;
use warnings;

use Log::Log4perl;
use POSIX;

use base ('pf::firewallsso');

use pf::accounting qw(node_accounting_current_sessionid);
use pf::config qw(%ConfigFirewallSSO);
use pf::constants qw($TRUE $FALSE);
use pf::node qw(node_view);
use pf::util::radius qw(perform_rsso);

sub description { 'Checkpoint Firewall' }

=head1 METHODS

=head2 action

Perform a radius accounting request based on the registered status of the node and his role.

=cut

sub action {
    my ($self, $firewall_conf, $method, $mac, $ip, $timeout) = @_;
    my $logger = Log::Log4perl::get_logger(ref($self));

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
        if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x' && $node_info->{'last_dot1x_username'} eq ''){
            $logger->info("We don't use the  dot1x username for the Firewall");
            return $FALSE;
        };
        my $acctsessionid = node_accounting_current_sessionid($mac);
        my $connection_info = {
          nas_ip => $firewall_conf,
          nas_port => $ConfigFirewallSSO{$firewall_conf}->{'port'},
          secret => $ConfigFirewallSSO{$firewall_conf}->{'password'},
        };

        my $attributes = {
            'Acct-Session-Id' =>  $acctsessionid,
            'Acct-Status-Type' => $method,
            'User-Name' => $username,
            'Session-Timeout' => $timeout,
            'Called-Station-Id' => '00:11:22:33:44:55',
            'Framed-IP-Address' => $ip,
            'Calling-Station-Id' => $mac,
        };
        my $vsa = [];

        perform_rsso($connection_info,$attributes,$vsa);
        $logger->info("$method sent to the Checkpoint firewall for the node $mac");
        return $TRUE;
    } else {
        return $FALSE;
    }
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

package pf::firewallsso::FortiGate;

=head1 NAME

pf::firewallsso::FortiGate

=head1 SYNOPSIS

The pf::firewallsso::FortiGate module implements an object oriented interface
to access and manage Aruba Wireless Controllers.

=cut


use strict;
use warnings;

use base ('pf::firewallsso');

use POSIX;
use Log::Log4perl;

use pf::config;
sub description { 'FortiGate Firewall' }
use pf::util::radius qw(perform_rsso);
use pf::node qw(node_view);
use pf::accounting qw(node_accounting_current_sessionid);

=item action

Blabla ... Perform a radius request based on the registered status of the node and his role.
We hardcode the NAS IP (Fortigate IP) and the secret for now.

TODO = make the IP and secret for Firewall dynamic (adding field in pf.conf and adminGUI)

=cut

sub action {
    my ($self,$firewall_conf,$method,$mac,$ip) = @_;
    my $logger = Log::Log4perl::get_logger(ref($self));

    my $node_info = node_view($mac);

    if (defined($node_info) && (ref($node_info) eq 'HASH') && $node_info->{'status'} eq $pf::node::STATUS_REGISTERED) {
        my $acctsessionid = node_accounting_current_sessionid($mac);
        my $connection_info = {
          nas_ip => $firewall_conf,
          nas_port => $ConfigFirewallSSO{$firewall_conf}->{'port'},
          secret => $ConfigFirewallSSO{$firewall_conf}->{'password'},
        };

        my $attributes = {
            'Acct-Session-Id' =>  $acctsessionid,
            'Acct-Status-Type' => $method,
            'User-Name' => $node_info->{'pid'},
            'Session-Timeout' => '0',
            'Class' => $node_info->{'category'},
            'Called-Station-Id' => '00:11:22:33:44:55',
            'Framed-IP-Address' => $ip,
            'Calling-Station-Id' => $mac,
            'Proxy-State' => 'fe80000000000000700fa698f0a9a42100007357',
        };

        my $vsa = [];

        perform_rsso($connection_info,$attributes,$vsa);
        $logger->info("Node registered, allowed to pass Firewall");
        return 1;
    } else {
        return 0;
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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

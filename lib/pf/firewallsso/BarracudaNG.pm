package pf::firewallsso::BarracudaNG;

=head1 NAME

pf::firewallsso::BarracudaNG

=head1 SYNOPSIS

The pf::firewallsso::BarracudaNG module implements an object oriented interface
to update the BarracudaNG user table.

=cut


use strict;
use warnings;

use base ('pf::firewallsso');

use POSIX;

use pf::config;
sub description { 'Barracuda NG Firewall' }
use pf::node qw(node_view);
use pf::log;
use Net::SSH2;

=head1 METHODS

=head2 action

Perform a ssh command based on the registered status of the node and his role.

=cut

sub action {
    my ($self,$firewall_conf,$method,$mac,$ip,$timeout) = @_;
    my $logger = get_logger();

    if ($method eq 'Start') {
        my $node_info = node_view($mac);
        my $username = $node_info->{'pid'};
        $username =  $node_info->{'last_dot1x_username'} if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x');
        return 0 if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x' && $node_info->{'last_dot1x_username'} eq '');

        my @categories = @{$self->{categories}};
        if ( defined($node_info) &&
            (ref($node_info) eq 'HASH') &&
            $node_info->{'status'} eq $pf::node::STATUS_REGISTERED &&
            (grep $_ eq $node_info->{'category'}, @categories)) {
            my $ssh;
            $ssh = Net::SSH2->new();
            $ssh->connect($firewall_conf, $ConfigFirewallSSO{$firewall_conf}->{'port'}) or die "Cannot connect $!"  ;
            $ssh->auth_password($ConfigFirewallSSO{$firewall_conf}->{'username'},$ConfigFirewallSSO{$firewall_conf}->{'password'}) or die "Cannot authenticate" ;
            my $chan = $ssh->channel();
            $chan->shell();
            print $chan "phibstest 127.0.0.1 l peer=".$ip." origin=PacketFence service=PacketFence user=".$username." \n";
            $logger->info("Node $mac and Username $username registered and allowed to pass the Barracuda Firewall"); 
            $ssh->disconnect();
                       
        }
    } elsif ($method eq 'Stop') {
        my $node_info = node_view($mac);
        my $username = $node_info->{'pid'};
        $username = $node_info->{'last_dot1x_username'} if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x');
        return 0 if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x' && $node_info->{'last_dot1x_username'} eq '');

        my @categories = @{$self->{categories}};
        if (defined($node_info) && (ref($node_info) eq 'HASH') &&
            $node_info->{'status'} eq $pf::node::STATUS_REGISTERED &&
            (grep $_ eq $node_info->{'category'}, @categories)
           ){
            my $ssh;
            $ssh = Net::SSH2->new();
            $ssh->connect($firewall_conf, $ConfigFirewallSSO{$firewall_conf}->{'port'}) or die "Cannot connect $!"  ;
            $ssh->auth_password($ConfigFirewallSSO{$firewall_conf}->{'username'},$ConfigFirewallSSO{$firewall_conf}->{'password'}) or die "Cannot authenticate" ;
            my $chan = $ssh->channel();
            $chan->shell();
            print $chan "phibstest 127.0.0.1 o peer=".$ip." origin=PacketFence service=PacketFence user=".$username." \n";
            $logger->info("Node $mac and Username $username removed from the Barracuda Firewall"); 
            $ssh->disconnect();
            }
    }
    return 0;
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

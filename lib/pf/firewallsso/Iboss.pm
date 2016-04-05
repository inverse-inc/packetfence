package pf::firewallsso::Iboss;

=head1 NAME

pf::firewallsso::Iboss

=head1 SYNOPSIS

The pf::firewallsso::Iboss module implements an object oriented interface
to update the Iboss user table.

=cut


use strict;
use warnings;

use base ('pf::firewallsso');

use POSIX();
use pf::log;

use pf::config qw(%ConfigFirewallSSO);
sub description { 'Iboss Appliance' }
use pf::node qw(node_view);
use LWP::UserAgent ();
use HTTP::Request::Common ();

#Export environement variables for LWP
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

=head1 METHODS

=head2 action

Perform a http get request based on the registered status of the node and his role.

=cut

my $ua = LWP::UserAgent->new;

sub action {
    my ($self,$firewall_conf,$method,$mac,$ip,$timeout) = @_;
    my $logger = get_logger();

    if ($method eq 'Start') {
        my $node_info = node_view($mac);
        my $username = $node_info->{'pid'};
        $username =  $node_info->{'last_dot1x_username'} if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x');
        return 0 if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x' && $node_info->{'last_dot1x_username'} eq '');

        my @categories = @{$self->{categories}};
        if (
            defined($node_info) &&
            (ref($node_info) eq 'HASH') &&
            $node_info->{'status'} eq $pf::node::STATUS_REGISTERED &&
            (grep $_ eq $node_info->{'category'}, @categories)
        ){
            # Create a request
            my $req = HTTP::Request->new(GET => "http://$firewall_conf:$ConfigFirewallSSO{$firewall_conf}->{'port'}/nacAgent?action=login&user=$username&dc=$ConfigFirewallSSO{$firewall_conf}->{'nac_name'}&key=$ConfigFirewallSSO{$firewall_conf}->{'password'}&ip=$ip&cn=$username&g=$node_info->{'category'}");
            #print $req;
            $req->content_type('application/x-www-form-urlencoded');
            $req->content('query=libwww-perl&mode=dist');

            # Pass request to the user agent and get a response back
            my $res = $ua->request($req);

            # Check the outcome of the response
            if ($res->is_success) {
                $logger->info("Username $username with node $mac is registered and authorized in the Iboss");
            }
            else {
                $logger->warn("Username $username with node $mac failed to register and not authorized in the Iboss");
            }
    }
    elsif ($method eq 'Stop') {
        my $node_info = node_view($mac);
        my $username = $node_info->{'pid'};
        $username = $node_info->{'last_dot1x_username'} if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x');
        return 0 if ( $ConfigFirewallSSO{$firewall_conf}->{'uid'} eq '802.1x' && $node_info->{'last_dot1x_username'} eq '');

        my @categories = @{$self->{categories}};
        if (
            defined($node_info) &&
            (ref($node_info) eq 'HASH') &&
            $node_info->{'status'} eq $pf::node::STATUS_REGISTERED &&
            (grep $_ eq $node_info->{'category'}, @categories)
        ){
            # Create a request
            my $req = HTTP::Request->new(GET => "http://$firewall_conf:$ConfigFirewallSSO{$firewall_conf}->{'port'}/nacAgent?action=logout&user=$username&dc=$ConfigFirewallSSO{$firewall_conf}->{'nac_name'}&key=$ConfigFirewallSSO{$firewall_conf}->{'password'}&ip=$ip&cn=$username&g=$node_info->{'category'}");
            #print $req;
            $req->content_type('application/x-www-form-urlencoded');
            $req->content('query=libwww-perl&mode=dist');

            # Pass request to the user agent and get a response back
            my $res = $ua->request($req);

            # Check the outcome of the response
            if ($res->is_success) {
                $logger->info("Username $username with node $mac is unregistered and logout from the Iboss");
            }
            else {
                $logger->warn("Username $username with node $mac failed to logout from the Iboss");
            }
         }
    }
    return 0;
    }
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

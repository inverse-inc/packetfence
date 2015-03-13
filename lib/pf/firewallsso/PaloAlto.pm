package pf::firewallsso::PaloAlto;

=head1 NAME

pf::firewallsso::PaloAlto

=head1 SYNOPSIS

The pf::firewallsso::PaloAlto module implements an object oriented interface
to update the PaloAlto user table.

=cut


use strict;
use warnings;

use base ('pf::firewallsso');

use POSIX;
use Log::Log4perl;

use pf::config;
sub description { 'PaloAlto Firewall' }
use pf::node qw(node_view);
use LWP::UserAgent;
use HTTP::Request::Common;

#Export environement variables for LWP
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

=head1 METHODS

=head2 action

Perform a xml api request based on the registered status of the node and his role.

=cut

sub action {
    my ($self,$firewall_conf,$method,$mac,$ip,$timeout) = @_;
    my $logger = Log::Log4perl::get_logger(ref($self));

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
            my $message = <<"XML";
                <uid-message>
                    <version>1.0</version>
                    <type>update</type>
                    <payload>
                        <login>
                            <entry name=\"$username\" ip=\"$ip\" timeout=\"$timeout\"/>
                        </login>
                    </payload>
               </uid-message>
XML
            my $webpage = "https://".$firewall_conf."/api/?type=user-id&action=set&key=".$ConfigFirewallSSO{$firewall_conf}->{'password'};
            my $ua = LWP::UserAgent->new;
            $ua->timeout(5);
            my $response = $ua->post($webpage, Content => [ cmd => $message ]);
            if ($response->is_success) {
                $logger->info("Node $mac registered and allowed to pass the Firewall");
                return 1;
            } else {
                $logger->error("XML send error :".$response->status_line);
                return 0;
            }
        }
    } elsif ($method eq 'Stop') {
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
            my $message = <<"XML";
                <uid-message>
                    <version>1.0</version>
                    <type>update</type>
                    <payload>
                        <logout>
                            <entry name=\"$username\" ip=\"$ip\"/>
                        </logout>
                    </payload>
               </uid-message>
XML
            my $webpage = "https://".$firewall_conf."/api/?type=user-id&action=set&key=".$ConfigFirewallSSO{$firewall_conf}->{'password'};
            my $ua = LWP::UserAgent->new;
            $ua->timeout(5);
            my $response = $ua->post($webpage, Content => [ cmd => $message ]);
            if ($response->is_success) {
                $logger->debug("Node $mac removed from the firewall");
                return 1;
            } else {
                $logger->error("XML send error :".$response->status_line);
                return 0;
            }
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

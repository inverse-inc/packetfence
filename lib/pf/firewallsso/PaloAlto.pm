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
use pf::log;

use pf::config qw(%ConfigFirewallSSO);
sub description { 'PaloAlto Firewall' }
use pf::node qw(node_view);
use LWP::UserAgent;
use HTTP::Request::Common;
use Net::Syslog;
use pf::constants::firewallsso qw($SYSLOG_TRANSPORT);

#Export environement variables for LWP
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

=head1 METHODS

=head2 action

Perform a xml api request based on the registered status of the node and his role.

=cut

sub action {
    my ($self,$firewall_conf,$method,$mac,$ip,$timeout) = @_;
    my $logger = $self->logger;

    if ($method eq 'Start') {
        my $node_info = node_view($mac);
        my $username = $node_info->{'pid'};

        my @categories = @{$self->{categories}};
        if (
            defined($node_info) &&
            (ref($node_info) eq 'HASH') &&
            $node_info->{'status'} eq $pf::node::STATUS_REGISTERED &&
            (grep $_ eq $node_info->{'category'}, @categories)
        ){
            if($ConfigFirewallSSO{$firewall_conf}->{'transport'} eq $SYSLOG_TRANSPORT) {
                return $self->send_sso_start_syslog($firewall_conf, $ip, $mac, $username, $timeout);
            }
            # Leaving everything except syslog to HTTP for backward compatibility
            else {
                return $self->send_sso_start_http($firewall_conf, $ip, $mac, $username, $timeout);
            }
        }
    } elsif ($method eq 'Stop') {
        my $node_info = node_view($mac);
        my $username = $node_info->{'pid'};

        my @categories = @{$self->{categories}};
        if (
            defined($node_info) &&
            (ref($node_info) eq 'HASH') &&
            $node_info->{'status'} eq $pf::node::STATUS_REGISTERED &&
            (grep $_ eq $node_info->{'category'}, @categories)
        ){
            if($ConfigFirewallSSO{$firewall_conf}->{'transport'} eq $SYSLOG_TRANSPORT) {
                return $self->send_sso_stop_syslog($firewall_conf, $ip, $mac, $username, $timeout);
            }
            # Leaving everything except syslog to HTTP for backward compatibility
            else {
                return $self->send_sso_stop_http($firewall_conf, $ip, $mac, $username, $timeout);
            }
        }
    }
    return 0;
}

=head2 logger

Return the current logger for the switch

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}

=head2 send_sso_start_syslog

Send an SSO start using sylog

=cut

sub send_sso_start_syslog {
    my ($self, $firewall_conf, $ip, $mac, $username, $timeout) = @_;
    my $syslog = Net::Syslog->new(SyslogHost => $firewall_conf);
    $syslog->send("Group <packetfence> User <$username> Address <$ip> assigned to session");
}

=head2 send_sso_stop_syslog

Does nothing as there doesn't seem to be a way to send an SSO stop using syslog for the Palo Alto

=cut

sub send_sso_stop_syslog {
    my ($self, $firewall_conf, $ip, $mac, $username, $timeout) = @_;
    $self->logger->info("SSO Stop is not supported for syslog transport, you should use the HTTP transport if you require it.");
}

=head2 send_sso_start_http

Send an SSO start using an HTTP API call

=cut

sub send_sso_start_http {
    my ($self, $firewall_conf, $ip, $mac, $username, $timeout) = @_;
    my $logger = $self->logger;
    $timeout = ( $timeout / 60 );   # Palo Alto XML API expects a timeout in minutes
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

=head2 send_sso_stop_http

Send an SSO stop using an HTTP API call

=cut

sub send_sso_stop_http {
    my ($self, $firewall_conf, $ip, $mac, $username, $timeout) = @_;
    my $logger = $self->logger;
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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

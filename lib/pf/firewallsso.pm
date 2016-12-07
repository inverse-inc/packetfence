package pf::firewallsso;

=head1 NAME

pf::firewallsso

=cut

=head1 DESCRIPTION

pf::firewallsso

This module is used for sending firewallsso request to the web api

=cut

use strict;
use warnings;

use pf::client;
use pf::config qw(
    %ConfigFirewallSSO
);
use pf::constants qw(
    $TRUE
    $FALSE
);
use pf::log;
use List::MoreUtils qw(any);
use NetAddr::IP;
use pf::cluster;

=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = get_logger();
   $logger->debug("instantiating new pf::firewallsso");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   $self->{id} = $argv{id};
   $self->{categories} = $argv{categories};
   $self->{networks} = $argv{networks};
   return $self;
}

sub should_sso {
    my ($self, $ip, $mac) = @_;
    my $logger = get_logger();
    my $ip_addr = NetAddr::IP->new($ip);
    if(@{$self->{networks}} eq 0){
        $logger->trace("Doing SSO on $self->{id} since it applies to any network");
        return $TRUE;
    }
    elsif(any { $_->contains($ip_addr) }@{$self->{networks}}){
        $logger->debug("Doing SSO on $self->{id} since IP belons to one of its networks");
        return $TRUE;
    }
    else {
        $logger->debug("Determined that SSO shouldn't be done on the node.");
        return $FALSE;
    }
}

=item do_sso

Send the firewall sso update request to the webapi.

=cut

sub do_sso {
    my ($self, $method, $mac, $ip, $timeout) = @_;
    return unless scalar keys %ConfigFirewallSSO;
    my $logger = get_logger();

    my $client = pf::client::getClient();

    my %data = (
       'method'           => $method,
       'mac'              => $mac,
       'ip'               => $ip,
       'timeout'          => $timeout
    );
    $logger->trace("Sending a firewallsso $method for ($mac,$ip) ");

    $client->notify('firewallsso', %data );

}

=item sso_source_ip

Computes which IP should be used as source IP address for the SSO

Takes into account the active/active clustering 

=cut

sub sso_source_ip {
    my ($self) = @_;
    if($cluster_enabled){
        pf::cluster::management_cluster_ip();
    }
    else {
        return $management_network->tag('vip') || $management_network->tag('ip');
    }
}


=back

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


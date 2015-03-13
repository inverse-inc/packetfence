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
use pf::config;
use pf::log;

=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = get_logger();
   $logger->debug("instantiating new pf::firewallsso");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   $self->{categories} = $argv{categories};
   return $self;
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


=back

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


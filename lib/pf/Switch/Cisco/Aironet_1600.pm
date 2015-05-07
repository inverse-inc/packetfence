package pf::Switch::Cisco::Aironet_1600;

=head1 NAME

pf::Switch::Cisco::Aironet_1600 - Object oriented module to access SNMP enabled Cisco Aironet 1600 APs

=head1 SYNOPSIS

The pf::Switch::Cisco::Aironet_1600 module implements an object oriented interface
to access SNMP enabled Cisco Aironet_1600 APs.

This modules extends pf::Switch::Cisco::Aironet

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;

use pf::config;
use pf::Switch::constants;
use pf::util;
use pf::accounting qw(node_accounting_current_sessionid);
use pf::util qw(format_mac_as_cisco);
use pf::node qw(node_attributes);
use pf::util::radius qw(perform_coa perform_disconnect);

use base ('pf::Switch::Cisco::Catalyst_2960');

sub description { 'Cisco Aironet 1600' }

=head2 deauthTechniques

Specifices the type of deauth

=cut

sub deauthTechniques {
    my ($this, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => 'deauthenticateMacRadius',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=head2 deauthenticateMacRadius

Method to deauth a wired node with CoA.

=cut

sub deauthenticateMacRadius {
    my ($this, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $mac = format_mac_as_cisco($mac);

    # perform CoA
    my $acctsessionid = node_accounting_current_sessionid($mac);
    $this->radiusDisconnect($mac);
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

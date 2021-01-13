package pf::UnifiedApi::Controller::Config::Networks;

=head1 NAME

pf::UnifiedApi::Controller::Config::Networks - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Networks



=cut

use strict;
use warnings;


use Mojo::Base qw(pf::UnifiedApi::Controller::Config::Subtype);

has 'config_store_class' => 'pf::ConfigStore::Network';
has 'form_class' => 'pfappserver::Form::Config::Network';
has 'primary_key' => 'network_id';

use pf::ConfigStore::Network;
use pfappserver::Form::Config::Network::dns_enforcement;
use pfappserver::Form::Config::Network::vlan_registration;
use pfappserver::Form::Config::Network::vlan_isolation;
use pfappserver::Form::Config::Network::inline;
use pfappserver::Form::Config::Network::inlinel2;
use pfappserver::Form::Config::Network::inlinel3;
use pfappserver::Form::Config::Network::other;
use pf::constants::config qw(
    $NET_TYPE_DNS_ENFORCEMENT
    $NET_TYPE_VLAN_REG
    $NET_TYPE_VLAN_ISOL
    $NET_TYPE_INLINE
    $NET_TYPE_INLINE_L2
    $NET_TYPE_INLINE_L3
    $NET_TYPE_OTHER
);

our %TYPES_TO_FORMS = (
   map { my $type = $_;$type=~s/-/_/g;$_ => "pfappserver::Form::Config::Network::$type" } (
       $NET_TYPE_DNS_ENFORCEMENT,
       $NET_TYPE_VLAN_REG,
       $NET_TYPE_VLAN_ISOL,
       $NET_TYPE_INLINE,
       $NET_TYPE_INLINE_L2,
       $NET_TYPE_INLINE_L3,
       $NET_TYPE_OTHER,
   )
);

sub type_lookup {
    return \%TYPES_TO_FORMS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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


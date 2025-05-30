package pf::UnifiedApi::Controller::Config::Connectors::DnsConnectors;

=head1 NAME

pf::UnifiedApi::Controller::Config::Connectors::DnsConnectors - 

=cut

=head1 DESCRIPTION

Configure dns connectors

=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::Connector::DnsConnectors';
has 'form_class' => 'pfappserver::Form::Config::Connector::DnsConnectors';
has 'primary_key' => 'dns_profile_id';

use pf::ConfigStore::Connectors::DnsConnectors;
use pfappserver::Form::Config::Connectors::DnsConnectors;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2025 Inverse inc.

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

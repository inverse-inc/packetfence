package pf::UnifiedApi::Controller::Config::ConnectionProfiles;

=head1 NAME

pf::UnifiedApi::Controller::Config::ConnectionProfiles -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::ConnectionProfiles

=cut

use strict;
use warnings;
use Mojo::Base qw(pf::UnifiedApi::Controller::Config);
use pf::ConfigStore::Profile;
use pfappserver::Form::Config::Profile;

has 'config_store_class' => 'pf::ConfigStore::Profile';
has 'form_class' => 'pfappserver::Form::Config::Profile';

our %DEFAULT_VALUES = (
    "access_registration_when_registered" => "",
    "always_use_redirecturl" => "",
    "autoregister" => "",
    "billing_tiers" => "",
    "block_interval" => 0,
    "description" => "",
    "device_registration" => "",
    "dot1x_recompute_role_from_portal" => "",
    "filter" => "",
    "id" => "",
    "login_attempt_limit" => 0,
    "logo" => "",
    "preregistration" => "",
    "provisioners" => "",
    "redirecturl" => "",
    "reuse_dot1x_credentials" => "",
    "root_module" => "",
    "scans" => "",
    "sms_pin_retry_limit" => 0,
    "sms_request_limit" => 0,
    "sources" => ""
);

sub default_values {
    \%DEFAULT_VALUES
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

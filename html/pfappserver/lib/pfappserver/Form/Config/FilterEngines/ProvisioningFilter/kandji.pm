package pfappserver::Form::Config::FilterEngines::ProvisioningFilter::kandji;

=head1 NAME

pfappserver::Form::Config::FilterEngines::ProvisioningFilter::kandji -

=head1 DESCRIPTION

pfappserver::Form::Config::FilterEngines::ProvisioningFilter::kandji

=cut

use strict;
use warnings;
use pfappserver::Form::Field::DynamicList;
use pfappserver::Form::Config::FilterEngines;
use pf::config qw(%Config);
use HTML::FormHandler::Moose;
use pf::constants::role qw(@ROLES);
use pf::constants::filters qw(@BASE_FIELDS @NODE_INFO_FIELDS @FINGERBANK_FIELDS @SWITCH_FIELDS @OWNER_FIELDS @SECURITY_EVENT_FIELDS);
use pfconfig::cached_hash;
tie our %ConfigProvisioningFiltersMeta, 'pfconfig::cached_hash', "config::ProvisioningFiltersMeta";
extends 'pfappserver::Form::Config::FilterEngines::ProvisioningFilter';

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

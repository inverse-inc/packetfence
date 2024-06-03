package pfappserver::Form::Config::Fleetdm;

=head1 NAME

pfappserver::Form::Config::Fleetdm - Web form for Fleetdm

=head1 DESCRIPTION

Form definition to create or update Fleetdm.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::log;
use pf::config;
use pf::util;
use pf::authentication;
use Sys::Hostname;

## Definition

has_field 'status' => (
    type            => 'Toggle',
    label           => 'Enabled',
    checkbox_value  => 'enabled',
    unchecked_value => 'disabled',
    default => 'enabled',
);

has_field 'host' =>
    (
        type => 'Text',
        label => 'host',
        required => 1,
        messages => { required => 'Host of FleetDM service' },
    );

has_field 'email' =>
    (
        type => 'Text',
        label => 'Email used to login FleetDM',
        required => 1,
        messages => { required => 'Please specify the email address for FleetDM' },
        tags => { after_element => \&help,
            help => 'The email address used for login fleetDM' },
    );

has_field 'password' =>
    (
        type => 'ObfuscatedText',
        label => 'Password to login FleetDM',
        required => 1,
        messages => { required => 'Please specify the password for FleetDM' },
        tags => { after_element => \&help,
            help => 'The password used for login fleetDM' },
    );

has_field 'token' =>
    (
        type => 'ObfuscatedText',
        label => 'Administrative API Token used to call FleetDM APIs. Administrative token must be a permanent token. Token will be used when both token and email / password are specified',
        tags => { after_element => \&help,
            help => 'The administrative API token to call FleetDM APIs' },
    );




=over

=back

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

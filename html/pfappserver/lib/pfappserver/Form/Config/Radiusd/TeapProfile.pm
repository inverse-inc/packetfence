package pfappserver::Form::Config::Radiusd::TeapProfile;

=head1 NAME

pfappserver::Form::Config::Radiusd::TeapProfile -

=head1 DESCRIPTION

pfappserver::Form::Config::Radiusd::TeapProfile

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
use pf::ConfigStore::Radiusd::TLSProfile;
extends 'pfappserver::Base::Form';
with qw(pfappserver::Base::Form::Role::Help);
## Definition
has_field 'id' =>
    (
        type => 'Text',
        label => 'Profile Name',
        required => 1,
        messages => { required => 'Please specify the name of the teap profile.' },
    );

has_field 'tls' =>
    (
        type => 'Select',
        required => 1,
        options_method => \&options_tls,
    );

has_field 'identity_types' =>
    (
        type => 'Select',
        required => 1,
        options_method => \&options_identity_types,
    );

has_field 'authority_identity' =>
    (
        type => 'Text',
        required => 1,
    );

has_field 'default_eap_type' =>
    (
        type    => 'Select',
        label   => 'Default EAP Type',
        required => 1,
        options => [
            map { { value => lc($_), label => $_ } }
              qw(MSCHAPv2 TLS GTC MD5)
        ],
    );

has_field 'user_eap_type' =>
    (
        type    => 'Select',
        label   => 'User EAP Type',
        required => 1,
        options => [
            map { { value => lc($_), label => $_ } }
              qw(MSCHAPv2 TLS GTC MD5)
        ],
    );

has_field 'machine_eap_type' =>
    (
        type    => 'Select',
        label   => 'Machine EAP Type',
        required => 1,
        options => [
            map { { value => lc($_), label => $_ } }
              qw(MSCHAPv2 TLS GTC MD5)
        ],
    );

sub options_tls {
    return  map { { value => $_, label => $_ } } @{pf::ConfigStore::Radiusd::TLSProfile->new->readAllIds};
}

sub options_identity_types {
    return map {{ value => $_, label => $_ }} ('machine,user', 'user,machine', 'user', 'machine');
}

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


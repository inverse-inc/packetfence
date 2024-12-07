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
        options_method => \&options_tls,
    );

has_field 'authority_identity' =>
    (
        type => 'Text',
    );

has_field 'pac_opaque_key' => (
    type     => 'Text',
    apply    => [
        {
            check   => sub { $_[0] =~ /^[0-9a-fA-F]+$/ },
            message => sub {
                my ( $value, $field ) = @_;
                return $field->name . " must be hexadecimal";
            },
        }
    ]
);

sub options_tls {
    return  map { { value => $_, label => $_ } } @{pf::ConfigStore::Radiusd::TLSProfile->new->readAllIds};
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


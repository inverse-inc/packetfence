package pfappserver::Form::Config::Authentication::Source::Eduroam;

=head1 NAME

pfappserver::Form::Config::Authentication::Source::Eduroam

=cut

=head1 DESCRIPTION

Form definition to create or update an Eduroam authentication source.

=cut

use strict;
use warnings;

use HTML::FormHandler::Moose;

extends 'pfappserver::Form::Config::Authentication::Source';
with 'pfappserver::Base::Form::Role::Help';

has_field 'tlrs1_server_address' => (
    type        => 'Text',
    label       => 'TLRS1 server address',
    required    => 1,
    tags        => {
        after_element   => \&help,
        help            => 'Eduroam TLRS1 server address',
    },
);

has_field 'tlrs2_server_address' => (
    type        => 'Text',
    label       => 'TLRS2 server address',
    required    => 1,
    tags        => {
        after_element   => \&help,
        help            => 'Eduroam TLRS2 server address',
    },
);

has_field 'tlrs_radius_secret' => (
    type        => 'Text',
    label       => 'TLRS RADIUS secret',
    required    => 1,
    tags        => {
        after_element   => \&help,
        help            => 'Eduroam TLRS RADIUS secret',
    },
);

has_field 'auth_listening_port' => (
    type            => 'PosInteger',
    label           => 'Authentication listening port',
    tags            => {
        after_element   => \&help,
        help            => 'PacketFence Eduroam RADIUS virtual server authentication listening port',
    },
    element_attr    => {
        placeholder     => pf::Authentication::Source::EduroamSource->meta->get_attribute('auth_listening_port')->default,
    },
    default         => pf::Authentication::Source::EduroamSource->meta->get_attribute('auth_listening_port')->default,
);

has_field 'acct_listening_port' => (
    type            => 'PosInteger',
    label           => 'Accounting listening port',
    tags            => {
        after_element   => \&help,
        help            => 'PacketFence Eduroam RADIUS virtual server accounting listening port',
    },
    element_attr    => {
        placeholder     => pf::Authentication::Source::EduroamSource->meta->get_attribute('acct_listening_port')->default,
    },
    default         => pf::Authentication::Source::EduroamSource->meta->get_attribute('acct_listening_port')->default,
);


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


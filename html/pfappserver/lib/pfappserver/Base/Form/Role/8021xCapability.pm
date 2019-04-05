package pfappserver::Base::Form::Role::8021xCapability;

=head1 NAME

pfappserver::Base::Form::Role::8021xCapability - Role for 802.1x capability

=cut

=head1 DESCRIPTION

pfappserver::Base::Form::Role::8021xCapability

=cut

use strict;
use warnings;
use pf::config qw(%Config);
use namespace::autoclean;
use HTML::FormHandler::Moose::Role;
with 'pfappserver::Base::Form::Role::Help';

has_field '8021x_capable' => (
    type => 'Toggle',
    checkbox_value => '1',
    unchecked_value => '0',
    label => 'Enable this source for 802.1x',
    default_method => \&default_from_attribute,
    tags => {
        after_element => \&help,
        help => 'Enable this source for 802.1x authentication, it will allow you to select it in the realm configuration.',
    },
);

has_block '8021xCapability' => (
    render_list => [qw(8021x_capable)],
);

=head2 default_from_attribute

Gets the default value for a field for the source attribute.

=cut

sub default_from_attribute {
    my ($field) = @_;
    my $source_class = $field->form->source_class;
    return $source_class->meta->get_attribute($field->name)->default;
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

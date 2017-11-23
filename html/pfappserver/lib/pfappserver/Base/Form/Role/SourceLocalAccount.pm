package pfappserver::Base::Form::Role::SourceLocalAccount;

=head1 NAME

pfappserver::Base::Form::Role::SourceLocalAccount - Role for Local Accounts

=cut

=head1 DESCRIPTION

pfappserver::Base::Form::Role::SourceLocalAccount

=cut

use strict;
use warnings;
use namespace::autoclean;
use HTML::FormHandler::Moose::Role;
with 'pfappserver::Base::Form::Role::Help';

has_field 'create_local_account' => (
    type => 'Toggle',
    checkbox_value => 'yes',
    unchecked_value => 'no',
    label => 'Create Local Account',
    default_method => \&default_from_attribute,
    tags => {
        after_element => \&help,
        help => 'Create a local account on the PacketFence system based on the username provided.',
    },
);

has_field 'local_account_logins' => (
    type => 'PosInteger',
    label => 'Amount of logins for the local account',
    default_method => \&default_from_attribute,
    tags => {
        after_element => \&help_list,
        help => 'The amount of times, the local account can be used after its created. 0 means infinite.'
    },
);

has_block 'local_account' => (
    render_list => [qw(create_local_account local_account_logins)],
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

Copyright (C) 2005-2017 Inverse inc.

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


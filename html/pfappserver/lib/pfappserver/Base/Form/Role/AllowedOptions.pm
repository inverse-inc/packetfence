package pfappserver::Base::Form::Role::AllowedOptions;

=head1 NAME

pfappserver::Base::Form::Role::AllowedOptions -

=cut

=head1 DESCRIPTION

pfappserver::Base::Form::Role::AllowedOptions

=cut

use namespace::autoclean;
use HTML::FormHandler::Moose::Role;

=head2 _get_allowed_options

Get the allowed options for the current user based off their role.

=cut

sub _get_allowed_options {
    my ($self,$option) = @_;
    return admin_allowed_options([$self->ctx->user->roles],$option);
}

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


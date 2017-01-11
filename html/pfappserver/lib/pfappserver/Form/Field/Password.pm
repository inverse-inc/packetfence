package pfappserver::Form::Field::Password;

=head1 NAME

pfappserver::Form::Field::Password - PacketFence password field

=head1 DESCRIPTION

This field extends Password to avoid autocompletion of all the password fields

=cut

use Moose;
extends 'HTML::FormHandler::Field::Password';
use namespace::autoclean;

has '+password' => ( default => 0 );

sub build_element_attr {
    return { autocomplete => 'off', readonly => 1, onmouseover => "this.removeAttribute('readonly');", onfocus=>"this.removeAttribute('readonly');" };
}
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

__PACKAGE__->meta->make_immutable;
1;

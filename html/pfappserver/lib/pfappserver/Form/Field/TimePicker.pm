package pfappserver::Form::Field::TimePicker;

=head1 NAME

pfappserver::Form::Field::TimePicker - to be used with the time picker
JavaScript widget

=head1 DESCRIPTION

This field is simply a text field to be formatted by a theme
(Form::Widget::Theme::Pf).

=cut

use Moose;
extends 'HTML::FormHandler::Field::Text';
use namespace::autoclean;

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

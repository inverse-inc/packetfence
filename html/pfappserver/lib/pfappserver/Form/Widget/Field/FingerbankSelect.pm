package pfappserver::Form::Widget::Field::FingerbankSelect;

=head1 NAME

pfappserver::Form::Widget::Field::FingerbankSelect

=head1 DESCRIPTION

A select field with a typeahead to add more options to it

=cut

use Moose::Role;
use HTML::FormHandler::Render::Util ('process_attrs');
with 'HTML::FormHandler::Widget::Field::Select';

has 'fingerbank_model' => (isa => 'Str', is => 'rw');

use namespace::autoclean;

=head2 render_element

Create a select field with a text widget to add more options through a typeahead

=cut

sub render_element {
    my ( $self, $result ) = @_;
    $result ||= $self->result;

    my $select = '';
    $select .= '<div class="control-group">'.
        '<input data-type-ahead-for="'.$self->fingerbank_model.'" data-add-to="'.$self->id.'"'.
        ' class="fingerbank-type-ahead" name="fingerbank-add-'.$self->id.'" data-provide="typeahead"'.
        ' id="fingerbank-add-'.$self->id.'" data-btn="#btn-fingerbank-add-'.$self->id.'" placeholder="'.$self->_localize('Add').' '.
        $self->label.' '.$self->_localize('from Fingerbank').'" value="" type="text">'.
        '<a href="#" class="btn-icon btn-icon-circle" id="btn-fingerbank-add-'.$self->id.'"'.$self->id.'><i class="icon-plus icon-white"></i></a>'.
        '</div>';
    $select .= HTML::FormHandler::Widget::Field::Select::render_element($self,$result);
    return $select;
}

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

1;


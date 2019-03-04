package pfappserver::Form::Widget::Field::Span;

=head1 NAME

pfappserver::Form::Widget::Field::Span - noneditable span

=head1 DESCRIPTION

Renders a uneditable pseudo-field as a span in a form.

Fixes a closing tag in the shipped version.

=cut

use Moose::Role;
use HTML::FormHandler::Render::Util ('process_attrs');
with 'HTML::FormHandler::Widget::Field::Span';
use HTML::Entities qw(encode_entities);

use namespace::autoclean;


sub render_element {
    my ( $self, $result ) = @_;
    $result ||= $self->result;

    my $output = '<span';
    $output .= ' id="' . $self->id . '"';
    $output .= process_attrs($self->element_attributes($result));
    $output .= '>'; # the shipped version is incorrectly closing the span tag
    if(defined $self->value) {
        if($self->can("escape_value") && $self->escape_value) {
            $output .= encode_entities($self->value);
        }
        else {
            $output .= $self->value;
        }
    }
    $output .= '</span>';
    return $output;
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

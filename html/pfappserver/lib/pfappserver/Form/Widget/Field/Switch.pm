package pfappserver::Form::Widget::Field::Switch;

=head1 NAME

pfappserver::Form::Widget::Field::Switch - on/off switch

=head1 DESCRIPTION

Renders a checkbox as a big on/off switch.

=cut

use Moose::Role;
use namespace::autoclean;
use HTML::FormHandler::Render::Util ('process_attrs');

sub render_element {
    my ( $self, $result ) = @_; 
    $result ||= $self->result;

    my $checkbox_value = $self->checkbox_value;
    my $output = qq[<div class="switch">\n]
        . '<input type="checkbox" name="'
        . $self->html_name . '" id="' . $self->id . '" value="'
        . $self->html_filter($checkbox_value) . '"';
    $output .= ' checked="checked"'
        if $result->fif eq $checkbox_value;
    $output .= process_attrs($self->element_attributes($result));
    $output .= ' /></div>';

    return $output;
}

sub render {
    my ( $self, $result ) = @_; 
    $result ||= $self->result;
    die "No result for form field '" . $self->full_name . "'. Field may be inactive." unless $result;
    my $output = $self->render_element( $result );
    return $self->wrap_field( $result, $output );
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

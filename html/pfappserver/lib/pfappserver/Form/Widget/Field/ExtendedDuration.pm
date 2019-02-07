package pfappserver::Form::Widget::Field::ExtendedDuration;

=head1 NAME

pfappserver::Form::Widget::Field::ExtendedDuration - extended duration complex widget

=head1 DESCRIPTION

This compound field is to be used only with the ExtendedDuration form field.

=cut

use Moose::Role;
with 'HTML::FormHandler::Widget::Field::Compound';

=head1 METHODS

=cut

sub render_element {
    my ( $self, $result ) = @_;
    $result ||= $self->result;

    my $output = '';
    my $toggle = 0;

    foreach my $subfield ( $self->sorted_fields ) {
        if ($subfield->{type} eq 'Toggle') {
            if ($toggle) {
                $output .= $self->render_subfield( $result, $subfield );
                $output .= '</div>';
            }
            else {
                $output .= '</div><div class="controls">';
                $output .= $self->render_subfield( $result, $subfield );
                $toggle = 1;
            }
        }
        else {
            $output .= $self->render_subfield( $result, $subfield );
        }
    }
    $output =~ s/^\n//; # remove newlines so they're not duplicated

    return $output;
}

sub set_disabled {
    my ($field) = @_;
    if ($field->can("fields")) {
        foreach my $subfield ($field->fields) {
            set_disabled($subfield);
        }
    }
    $field->set_element_attr("disabled" => "disabled");
}

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

1;

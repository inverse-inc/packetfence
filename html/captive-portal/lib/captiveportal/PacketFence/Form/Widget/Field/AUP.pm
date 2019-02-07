package captiveportal::PacketFence::Form::Widget::Field::AUP;

=head1 NAME

captiveportal::PacketFence::Form::Widget::Field::AUP

=head1 DESCRIPTION

AUP Widget

=cut

use Moose::Role;
with 'HTML::FormHandler::Widget::Field::Checkbox';

=head2 render_element

Render the AUP with its checkbox

=cut

sub render_element {
    my ($self, $result) = @_;
    my $checkbox = HTML::FormHandler::Widget::Field::Checkbox::render_element($self, $result);
    my $divs = '';
    $divs .= '<div class="o-aup">'.$self->form->app->_render($self->form->app->current_module ? $self->form->app->current_module->aup_template() : "aup_text.html").'</div>';
    $divs .= '<div class="text-center u-padding-top">'.$checkbox.'<label tabindex=0 for="'.$self->id.'" class="tabbable c-btn c-btn--primary u-1/1 u-2/3@tablet u-3/5@desktop">'.
      $self->form->app->i18n('I accept the terms').'</label></div>';

    return $divs;
}

=head2 render

Render the field

=cut

sub render {
    my ($self, $result) = @_;
    $result ||= $self->result;
    die "No result for form field '" . $self->full_name . "'. Field may be inactive." unless $result;
    return $self->render_element( $result );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

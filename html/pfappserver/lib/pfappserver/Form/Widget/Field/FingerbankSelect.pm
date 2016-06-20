package pfappserver::Form::Widget::Field::FingerbankSelect;

=head1 NAME

pfappserver::Form::Widget::Field::ButtonGroup - radio buttons bootstrap-style

=head1 DESCRIPTION

This field extends the default RadioGroup and renders it as a series of links
as possible in Bootstrap.

=cut

use Moose::Role;
use HTML::FormHandler::Render::Util ('process_attrs');
with 'HTML::FormHandler::Widget::Field::Select';

use namespace::autoclean;

sub render_element {
    my ( $self, $result ) = @_;
    $result ||= $self->result;

    my $select = HTML::FormHandler::Widget::Field::Select::render_element($self,$result);
    $select .= '<div>'.
        '<input id="fingerbank-add-'.$self->id.'" placeholder="Add '.$self->label.' from Fingerbank" value="" type="text">'.
        '<button>+</button>'.
        '</div>';
    return $select;
}

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


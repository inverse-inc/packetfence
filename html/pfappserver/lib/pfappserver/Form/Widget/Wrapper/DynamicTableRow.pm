package pfappserver::Form::Widget::Wrapper::DynamicTableRow;

=head1 NAME

pfappserver::Form::Widget::Wrapper::Table add documentation

=cut

=head1 DESCRIPTION

pfappserver::Form::Widget::Wrapper::Table

=cut

use Moose::Role;
with 'HTML::FormHandler::Widget::Wrapper::Bootstrap';
use HTML::FormHandler::Render::Util ('process_attrs');

around wrap_field => sub {
    my ($orig, $self, $result, $rendered_widget ) = @_;
    my $class = $self->get_tag("dynamic_row_class");
    $class = " class=\"$class\"" if $class;
    my $extra = "<td>";
    $extra ="<td class=\"sort-handle\">" . ($self->name + 1) . "</td>\n<td>" if $self->parent->sortable ;
    return "<tr${class}>${extra}" . $rendered_widget .
         '</td><td class="action"><a class="btn-icon" href="#delete"><i class="icon-minus-circle"></i></a><a class="btn-icon" href="#add"><i class="icon-plus-circle"></i></a></td></tr>';
};

use namespace::autoclean;
1;

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


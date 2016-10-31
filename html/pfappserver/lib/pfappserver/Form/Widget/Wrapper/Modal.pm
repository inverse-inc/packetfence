package pfappserver::Form::Widget::Wrapper::Modal;

=head1 NAME

pfappserver::Form::Widget::Wrapper::Table add documentation

=cut

=head1 DESCRIPTION

pfappserver::Form::Widget::Wrapper::Table

=cut

use Moose::Role;
with 'HTML::FormHandler::Widget::Wrapper::Bootstrap';
use HTML::FormHandler::Render::Util ('process_attrs');
use pf::log;

around wrap_field => sub {
    my ($orig, $self, $result, $rendered_widget ) = @_;
    my $output = '';
#    use Data::Dumper;get_logger->info(Dumper($self));
    my $modal_id = "modal_" . $self->parent->name . "_" . $self->name;
    $output .= '<div class="control-group">';
    $output .= "<a href=\"#$modal_id\" class=\"btn\" data-toggle=\"modal\">Launch demo modal</a>";
    $output .= "<div class=\"modal fade hide\" id=\"" . $modal_id  . "\">";
    $output .= '<div class="modal-header">';
    $output .= '      <a class="close" data-dismiss="modal">&times;</a>';
    $output .= '      <h3><i></i> <span></span></h3>';
    $output .= '</div>';
    $output .= "<div class=\"modal-body\">$rendered_widget</div>";
    $output .= '<div class="modal-footer">';
    $output .= '      <a class="close" data-dismiss="modal">&times;</a>';
    $output .= '</div>';
    $output .= "</div>";
    $output .= "</div>";
    return $output;
};

use namespace::autoclean;
1;

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


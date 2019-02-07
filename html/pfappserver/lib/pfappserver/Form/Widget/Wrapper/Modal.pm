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
    my $parent_name = $self->parent->name;
    my $name = $self->name;
    my $id = "modal_${parent_name}_${name}";
    $output .= qq{<div class="control-group">};
    $output .= qq{<a href="#$id" class="btn" data-toggle="modal">$parent_name $name</a>};
    $output .= qq{<div class="modal fade hide" id="$id">};
    $output .= qq{<div class="modal-header">};
    $output .= qq{      <a class="close" data-dismiss="modal">&times;</a>};
    $output .= qq{      <h3><i></i> <span></span></h3>};
    $output .= qq{</div>};
    $output .= qq{<div class="modal-body">$rendered_widget</div>};
    $output .= qq{<div class="modal-footer">};
    $output .= qq{      <a class="close" data-dismiss="modal">&times;</a>};
    $output .= qq{</div>};
    $output .= qq{</div>};
    $output .= qq{</div>};
    return $output;
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


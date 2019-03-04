package pfappserver::Base::Form::Role::Defaults;

=head1 NAME

pfappserver::Base::Form::Role::Defaults

=head1 DESCRIPTION

This roles provides defaults

=cut

use namespace::autoclean;
use HTML::FormHandler::Moose::Role;

=head2 defaults_list

Format the default values for a list (CSV)

=cut

sub defaults_list {
    my $self = shift;

    my $id = $self->_localize($self->label);
    my $content;
    foreach my $element (split(',', $self->get_tag('defaults'))){
        $content .= "<span class=\"label label-info\" >$element</span>";
    }
    if ($self->get_tag('defaults')) {
        return sprintf("<div class='list-defaults alert alert-info'><strong>Built-in $id :</strong> %s</div>", $content);
    }
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

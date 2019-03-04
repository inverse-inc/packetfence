package pfappserver::Base::Form::Role::Help;

=head1 NAME

pfappserver::Base::Form::Role::Help

=head1 DESCRIPTION

This roles provides help and help_list

=cut

use namespace::autoclean;
use HTML::FormHandler::Moose::Role;

=head2 help

=cut

sub help {
    my $self = shift;
    my $help = undef;

    if ($self->get_tag('help')) {
        return sprintf('<p class="help-block">%s</p>', $self->_localize($self->get_tag('help')));
    }
}

=head2 help_list

=cut

sub help_list {
    my $self = shift;
    my $help = undef;

    if ($self->get_tag('help')) {
        return sprintf('<dl class="help-block">%s</dl>', $self->_localize($self->get_tag('help')));
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

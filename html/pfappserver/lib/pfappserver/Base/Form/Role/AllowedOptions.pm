package pfappserver::Base::Form::Role::AllowedOptions;

=head1 NAME

pfappserver::Base::Form::Role::AllowedOptions -

=cut

=head1 DESCRIPTION

pfappserver::Base::Form::Role::AllowedOptions

=cut

use namespace::autoclean;
use HTML::FormHandler::Moose::Role;

use pf::admin_roles;

has user_roles => (is => 'rw', default => sub { [] });

=head2 _get_allowed_options

Get the allowed options based of the

=cut

sub _get_allowed_options {
    my ($self, $option) = @_;
    return admin_allowed_options($self->user_roles, $option);
}

=head2 allowed_access_levels

The list of allowed access levels

=cut

sub allowed_access_levels {
    my ($self) = @_;
    my @options_values = $self->_get_allowed_options('allowed_access_levels');
    unless( @options_values ) {
        @options_values = keys %ADMIN_ROLES;
    }

    return @options_values;
}

around ACCEPT_CONTEXT => sub {
    my ($orig, $self, $c, @args) = @_;
    return $self->$orig($c, user_roles => [$c->user->roles], @args);
};

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


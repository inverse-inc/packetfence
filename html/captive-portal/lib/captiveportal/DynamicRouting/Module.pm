package captiveportal::DynamicRouting::Module;

=head1 NAME

DynamicRouting::Module

=head1 DESCRIPTION

Base Module for Dynamic Routing

=cut

use Moose;

has 'id' => (is => 'rw', required => 1);

has session => (is => 'rw', build => 1, lazy => 1);

has new_node_info => (is => 'rw', build => 1, lazy => 1);

has app => (is => 'ro', required => 1, isa => 'DynamicRouting::Application');

has parent => (is => 'ro', required => 1, isa => 'DynamicRouting::Module');

has username => (is => 'rw');

after 'username' => sub {
    my ($self, $username) = @_;
    $self->new_node_info->{pid} = $self->username;
    $self->app->session->{username} = $self->username;
};

sub _build_session {
    my ($self) = @_;
    return $self->app->session()->{"module_".$self->id};
}

# Validate that the reference will be updated!!!
sub _build_new_node_info {
    my ($self) = @_;
    return $self->app->session()->{"new_node_info"};
}

sub execute {
    my ($self) = @_;
    $self->execute_child();
}

sub execute_child {
    # implement me in subclasses
}

sub done {
    my ($self) = @_;
    $self->execute_actions();
    $self->parent->next();
}

sub next {
    my ($self) = @_;
    $self->done();
}

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

__PACKAGE__->meta->make_immutable;

1;


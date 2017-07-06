package captiveportal::PacketFence::DynamicRouting::Module::SelectRole;

=head1 NAME

DynamicRouting::Module::Message

=head1 DESCRIPTION

Module to show a message to the user

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';

use pf::nodecategory;

has 'template' => (is => 'rw', default => sub {'select-role.html'});

has 'admin_role' => (is => 'rw', required => 1);

=head2 execute_child

Display the message to the user and handle the continue if applicable

=cut

sub execute_child {
    my ($self) = @_;
    if($self->new_node_info->{category} eq $self->admin_role) {
        if(my $new_role = $self->app->request->param('new_role')) {
            $self->new_node_info->{category} = $new_role;
            $self->done();
        }
        else {
            $self->render($self->template, {
                title => $self->description,
                roles => [ grep { $_ ne $self->admin_role } map { $_->{name} } nodecategory_view_all() ], 
            });
        }
    }
    else {
        $self->done();
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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



package captiveportal::PacketFence::DynamicRouting::Module::SelectRole;

=head1 NAME

DynamicRouting::Module::SelectRole

=head1 DESCRIPTION

Module to select a new role for the device being registered

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';

use List::MoreUtils qw(any);
use pf::nodecategory;

has 'template' => (is => 'rw', default => sub {'select-role.html'});

has 'admin_role' => (is => 'rw', required => 1);

has 'list_role' => (is => 'rw', required => 1);

=head2 execute_child

Select a new role for the device being registered

=cut

sub execute_child {
    my ($self) = @_;
    my @roles = _split_roles($self->admin_role);
    if(any { $_ eq $self->new_node_info->{category}} @roles) {
        my @allowed_roles = $self->allowed_roles;
        my $new_role = $self->app->request->param('new_role');
        if (defined($new_role) && length($new_role)) {
            if (any { $_ eq $new_role } @allowed_roles) {
                $self->new_node_info->{category} = $new_role;
                $self->done();
                return;
            }
            $self->app->flash->{error} = "The selected role is not allowed.";
        }
        $self->render($self->template, {
            title => $self->description,
            roles => \@allowed_roles,
        });
    }
    else {
        $self->done();
    }
}

=head2 allowed_roles

The roles that can be selected: the roles of list_role that are not in
admin_role

=cut

sub allowed_roles {
    my ($self) = @_;
    my %admin_roles = map { $_ => 1 } _split_roles($self->admin_role);
    return grep { !$admin_roles{$_} } _split_roles($self->list_role);
}

sub _split_roles {
    my ($roles) = @_;
    return grep { length } split(/[\s,]+/, $roles // '');
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;



package captiveportal::Role::Routed;

=head1 NAME

captiveportal::Role::Routed

=head1 DESCRIPTION

Routing role to apply on a module

=cut

use Moose::Role;
use pf::log;

has 'route_map' => (is => 'rw', default => sub{ {} });

=head2 around execute_child

Route to the appropriate method if necessary

=cut

around 'execute_child' => sub {
    my $orig = shift;
    my $self = shift;

    my $method = $self->path_method('/'.$self->app->request->path());
    if(defined($method)){
        $method->($self);
    }
    else {
        $self->$orig();
    }
};

=head2 path_method

Get the method associated to a path if it exists

=cut

sub path_method {
    my ($self, $path) = @_;
    foreach my $regex (keys %{$self->route_map}){
        get_logger->debug("Checking if $path matches $regex");
        if($path =~ /^$regex$/){
            get_logger->debug("Found a route match : $regex");
            return $self->route_map->{$regex};
        }
    }
    return undef;
}

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


package captiveportal::DynamicRouting::Routed;

=head1 NAME

captiveportal::DynamicRouting::Routed

=head1 DESCRIPTION

Routing role to apply on a module

=cut

use Moose::Role;
use pf::log;

has 'route_map' => (is => 'rw', default => sub{ {} });

around 'execute_child' => sub {
    my $orig = shift;
    my $self = shift;

    foreach my $regex (keys %{$self->route_map}){
        my $path = '/'.$self->app->request->path();
        get_logger->debug("Checking if $path matches $regex");
        if($path =~ /^$regex$/){
            get_logger->debug("Found a route match : $regex");
            $self->route_map->{$regex}->($self);
            return;
        }
    }
    $self->$orig();
};

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


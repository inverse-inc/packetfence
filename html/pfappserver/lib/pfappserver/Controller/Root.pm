package pfappserver::Controller::Root;

=head1 NAME

pfappserver::Controller::Root - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');


=head1 METHODS

=over

=item index

The root page (/)

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # Redirect to the configurator
    $c->response->redirect($c->uri_for($c->controller('Configurator')->action_for('index')));
    $c->detach();
}

=item default

Standard 404 error page

=cut
sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=item end

Attempt to render a view, if needed.

=cut
sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;

    if ( scalar @{$c->error}) {
        for my $error ( @{ $c->error } ) {
            $c->log->error($error);
        }
        $c->stash->{status_msg} = 'An error condition has occured. See server side logs for details.';
        $c->response->status(500);
        $c->clear_errors;
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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

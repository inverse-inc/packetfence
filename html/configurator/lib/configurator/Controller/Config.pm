package configurator::Controller::Config;

=head1 NAME

configurator::Controller::Config - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

# Catalyst includes
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 SUBROUTINES

=over

=item get

Retrieve a configuration parameter in session

Usage: /config/<section>/<parameter>/get

=cut
sub get :Chained('object') :PathPart('get') :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{value} = $c->session->{$c->stash->{section} . "." . $c->stash->{parameter}};
}

=item object

=cut
sub object :Chained('/') :PathPart('config') :CaptureArgs(2) {
    my ( $self, $c, $section, $parameter ) = @_;

    $c->stash->{section}    = $section;
    $c->stash->{parameter}  = $parameter;
}

=item set

Set a configuration parameter in session for future write

Usage: /config/<section>/<parameter>/set/<value>

=cut
sub set :Chained('object') :PathPart('set') :Args(1) {
    my ( $self, $c, $value ) = @_;

    $c->session->{$c->stash->{section} . "." . $c->stash->{parameter}} = $value;
}

=item unset

Unset a configuration parameter from session for future write

Usage: /config/<section>/<parameter>/unset

=cut
sub unset :Chained('object') :PathPart('unset') :Args(0) {
    my ( $self, $c ) = @_;

    $c->session->{$c->stash->{section} . "." . $c->stash->{parameter}} = "";
}

=back

=head1 AUTHORS

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

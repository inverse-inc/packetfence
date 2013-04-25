package pfappserver::Controller::Config;

=head1 NAME

pfappserver::Controller::Config - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head1 METHODS

=over

=item delete

Delete a configuration parameter from session

Usage: /config/<section>/<parameter>/delete

=cut

#sub delete :Chained('object') :PathPart('delete') :Args(0) {
#    my ( $self, $c ) = @_;
#
#    $c->session->{$c->stash->{section} . "." . $c->stash->{parameter}} = "";
#}

=item object

=cut

#sub object :Chained('/') :PathPart('config') :CaptureArgs(2) {
#    my ( $self, $c, $section, $parameter ) = @_;
#
#    $c->stash->{section}    = $section;
#    $c->stash->{parameter}  = $parameter;
#}

=item read

Read a configuration parameter in session

Usage: /config/<section>/<parameter>/read

=cut

#sub read :Chained('object') :PathPart('read') :Args(0) {
#    my ( $self, $c ) = @_;
#
#    $c->stash->{value} = $c->session->{$c->stash->{section} . "." . $c->stash->{parameter}};
#}

=item update

Create/update a configuration parameter in session

Usage: /config/<section>/<parameter>/update/<value>

=cut

#sub update :Chained('object') :PathPart('update') :Args(1) {
#    my ( $self, $c, $value ) = @_;
#
#    $c->session->{$c->stash->{section} . "." . $c->stash->{parameter}} = $value;
#}

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

package pfappserver::Controller::Configuration::Wrix;

=head1 NAME

pfappserver::Controller::Configuration::Wrix - Catalyst Controller

=head1 DESCRIPTION


=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use DateTime;

use pf::util qw(sort_ip);

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
#Reconfigure the object dispatcher from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'configuration/wrix', CaptureArgs => 1 }
    },
    action_args => {
#Setting the global model and form for all actions
        '*' => { model => "Config::Wrix",form => "Config::Wrix" },
    },
);

=head1 METHODS

=head2 index

Usage: /configuration/wrix/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->forward('list');
}

sub export :Local {
    my ($self,$c) = @_;
    my $form = $self->getForm($c);
    my @columns = grep { $_ ne 'id' }  map { $_->name  } $form->fields;
    $c->forward('list');

    $c->stash->{current_view} = 'CSV';
    $c->stash(
        'now' => DateTime->now,
        'columns' => \@columns,
    );
}

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

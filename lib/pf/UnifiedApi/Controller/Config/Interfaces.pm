package pf::UnifiedApi::Controller::Config::Interfaces;

=head1 NAME

pf::UnifiedApi::Controller::Config::Interfaces -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Interfaces

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pfappserver::Model::Interface;
use Data::Dumper;

sub model {
    my $model = pfappserver::Model::Interface->new;
    $model->ACCEPT_CONTEXT;
    return $model;
}

sub list {
    my ($self) = @_;
    $self->render(json => {items => [$self->model->_listInterfaces('all')]}, status => 200);
}

sub resource{
    my ($self) = @_;
    return $self->get();
}

sub get {
    my ($self) = @_;
    $self->render(json => $self->model->get($self->stash->{interface_id}), status => 200);
}

sub create {
    my ($self) = @_;
    print Dumper($self->parse_json);
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

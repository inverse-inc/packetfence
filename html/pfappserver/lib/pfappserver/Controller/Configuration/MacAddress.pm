package pfappserver::Controller::Configuration::MacAddress;

=head1 NAME

pfappserver::Controller::Configuration::MacAddress - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;

use pf::util qw(load_oui download_oui);

BEGIN { extends 'pfappserver::Base::Controller::Base'; }

=head2 index

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->stash(template => 'configuration/macaddress/simple_search.tt') ;
    $c->forward('simple_search');
}

=head2 simpl_esearch

=cut

sub simple_search :SimpleSearch('MacAddress') :Local :Args() { }

=head2 update

=cut

sub update : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'JSON';
    my ($status, $status_msg) = download_oui();
    load_oui(1);
    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg;
}

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

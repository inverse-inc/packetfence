package pfappserver::Controller::Node;

=head1 NAME

pfappserver::Controller::Node - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 SUBROUTINES

=head2 auto

Allow only authenticated users

=cut
sub auto :Private {
    my ($self, $c) = @_;

    unless ($c->user_exists()) {
        # Try to redirect the user to the referer page once logged in
        my $base = $c->req->base;
        my $redirect_action = substr($c->req->referer, length($base) - 1) # Keep a leading slash
          if ($c->req->referer =~ m/^$base/);

        $c->response->status(HTTP_UNAUTHORIZED);
        $c->stash->{status_msg} = sprintf("You must <a href=\"%s\">login</a> to view this page.",
                                          $c->uri_for($c->controller('Admin')->action_for('login'),
                                                      undef,
                                                      { redirect_action => $redirect_action }));
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
}

=head2 index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->redirect($c->uri_for($c->controller('Node')->action_for('search')));
}

=head2 search

=cut
sub search :Path('search') :Args(0) {
    my ( $self, $c ) = @_;
    my ($filter, $status, $result, $nodes_ref, $count);

    my $page_num = $c->request->params->{'page_num'} || 1;
    my $per_page = $c->request->params->{'per_page'} || 25;
    my $limit_clause = "LIMIT " . (($page_num-1)*$per_page) . "," . $per_page;
    my %params = ( limit => $limit_clause );
    
    if (exists($c->req->params->{'filter'})) {
        $filter = $c->req->params->{'filter'};
        $params{'where'} = { type => 'any', like => $filter };
    }

    ($status, $result) = $c->model('Node')->search(%params);
    if (is_success($status)) {
        $nodes_ref = $result;
        ($status, $result) = $c->model('Node')->countAll(%params);
    }
    if (is_success($status)) {
        $count = $result;
        $c->stash->{page_num} = $page_num;
        $c->stash->{per_page} = $per_page;
        $c->stash->{nodes} = $nodes_ref;
        $c->stash->{count} = $count;
        $c->stash->{pages_count} = int($count/$per_page);
    }
    else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 object

Node controller dispatcher

=cut
sub object :Chained('/') :PathPart('node') :CaptureArgs(1) {
    my ( $self, $c, $mac ) = @_;

    my ($status, $node_ref) = $c->model('Node')->exists($mac);
    unless ( is_success($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $node_ref;
        #$c->response->redirect($c->uri_for($self->action_for('list')));
        $c->detach();
    }

    $c->stash->{mac} = $mac;
}

=head2

=cut
sub get :Chained('object') :PathPart('get') :Args(0) {
    my ( $self, $c ) = @_;

    my $node_ref = $c->model('Node')->get($c->stash->{mac});
    $c->stash->{node} = $node_ref;
}

=head1 AUTHOR

Francis Lachapelle <flachapelle@inverse.ca>

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

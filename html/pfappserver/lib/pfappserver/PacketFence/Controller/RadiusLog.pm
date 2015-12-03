package pfappserver::PacketFence::Controller::RadiusLog;

=head1 NAME

pfappserver::PacketFence::Controller::RadiusLog - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;

BEGIN { extends 'pfappserver::Base::Controller'; }

__PACKAGE__->config(
    action_args => {
        '*' => { model => 'RadiusLog' },
        advanced_search => { model => 'Search::RadiusLog', form => 'AdvancedSearch' },
        'simple_search' => { model => 'Search::RadiusLog', form => 'AdvancedSearch' },
        search => { model => 'Search::RadiusLog', form => 'AdvancedSearch' },
        'index' => { model => 'Search::RadiusLog', form => 'AdvancedSearch' },
    }
);

=head1 SUBROUTINES

=head2 index

=cut

sub index :Path :Args(0) :AdminRole('RADIUS_LOG_READ') {
    my ( $self, $c ) = @_;
    $c->stash(template => 'radiuslog/search.tt', from_form => "#empty");
    $c->go('search');
}

=head2 search

Perform an advanced search using the Search::RadiusLog model

=cut

sub search :Local :Args() :AdminRole('RADIUS_LOG_READ') {
    my ($self, $c, $pageNum, $perPage) = @_;
    $pageNum = 1 unless $pageNum;
    $perPage = 25 unless $perPage;
    $c->stash({
        columns => \@pf::radius_audit_log::FIELDS,
    });
}

=head2 simple_search

Perform an advanced search using the Search::RadiusLog model

=cut

sub simple_search :Local :Args() :AdminRole('RADIUS_LOG_READ') {
    my ($self, $c) = @_;
    $c->forward('search');
    $c->stash(template => 'radiuslog/search.tt', from_form => "#simpleSearch");
}

=head2 advanced_search

Perform an advanced search using the Search::RadiusLog model

=cut

sub advanced_search :Local :Args() :AdminRole('RADIUS_LOG_READ') {
    my ($self, $c) = @_;
    $c->forward('search');
    $c->stash(template => 'radiuslog/search.tt', from_form => "#advancedSearch");
}


=head2 object

controller dispatcher

=cut

sub object :Chained('/') :PathPart('radiuslog') :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    my ($status, $item_data) = $c->model('RadiusLog')->view($id);
    if ( is_error($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $item_data;
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
    $c->stash({
        item => $item_data,
        item_id => $id,
    });
}

=head2 view

=cut

sub view :Chained('object') :PathPart('read') :Args(0) :AdminRole('RADIUS_LOG_READ') {
    my ($self, $c) = @_;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

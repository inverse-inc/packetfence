package pfappserver::PacketFence::Controller::Auditing::DnsLog;

=head1 NAME

pfappserver::PacketFence::Controller::Auditing::DnsLog - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;
use pf::authentication;
use pf::ConfigStore::SwitchGroup;
use pf::ConfigStore::Switch;
use pf::ConfigStore::Profile;
use pf::ConfigStore::Domain;
use pf::ConfigStore::Realm;
use pf::dns_audit_log;


BEGIN { extends 'pfappserver::Base::Controller'; }

__PACKAGE__->config(
    action_args => {
        '*' => { model => 'Auditing::DnsLog' },
        advanced_search => { model => 'Auditing::DnsLog', form => 'DnsLogSearch' },
        'simple_search' => { model => 'Auditing::DnsLog', form => 'DnsLogSearch' },
        search => { model => 'Auditing::DnsLog', form => 'DnsLogSearch' },
        'index' => { model => 'Auditing::DnsLog', form => 'DnsLogSearch' },
    }
);

=head1 SUBROUTINES

=head2 index

=cut

sub index :Path :Args(0) :AdminRole('DNS_LOG_READ') {
    my ( $self, $c ) = @_;
#    $c->stash(template => 'dnslog/search.tt', from_form => "#empty");
#
    my $id = $c->user->id;
    my ($status, $saved_searches) = $c->model("SavedSearch::DnsLog")->read_all($id);
    $c->stash({
        saved_searches => $saved_searches,
        saved_search_form => $c->form("SavedSearch"),
    });

    $c->forward('search');
}

=head2 search

Perform an advanced search using the Search::Auditing::DnsLog model

=cut

sub search :Local :Args(0) :AdminRole('DNS_LOG_READ') {
    my ($self, $c) = @_;
    my $model = $self->getModel($c);
    my $form = $self->getForm($c);
    my $request = $c->request;
    my ($status, $result);
    $form->process(params => $request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $c->stash(
            current_view => 'JSON',
            status_msg => $form->field_errors
        );
    }
    else {
        my $query = $form->value;
        $c->stash($query);
        ($status, $result) = $model->search($query);
        if (is_success($status)) {
            $c->stash(form => $form);
            $c->stash($result);
        }
    }

    if ($request->param('export')) {
        $c->stash({
            current_view => 'CSV',
            columns      => [@pf::dns_audit_log::FIELDS,],
        });
    }
    else {
        $c->stash({
            columns => [sort @pf::dns_audit_log::FIELDS],
            display_columns => [qw(mac qname answer)],
        });
    }
    $c->response->status($status);
}

=head2 simple_search

Perform an advanced search using the Search::Auditing::DnsLog model

=cut

sub simple_search :Local :Args() :AdminRole('DNS_LOG_READ') {
    my ($self, $c) = @_;
    $c->forward('search');
    $c->stash(template => 'dnslog/search.tt', from_form => "#simpleSearch");
}

=head2 advanced_search

Perform an advanced search using the Search::Auditing::DnsLog model

=cut

sub advanced_search :Local :Args() :AdminRole('DNS_LOG_READ') {
    my ($self, $c) = @_;
    $c->forward('search');
    $c->stash(template => 'dnslog/search.tt', from_form => "#advancedSearch");
}


=head2 object

controller dispatcher

=cut

sub object :Chained('/') :PathPart('dnslog') :CaptureArgs(1) {
    my ( $self, $c, $id ) = @_;

    my ($status, $item_data) = $c->model('Auditing::DnsLog')->view($id);
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

sub view :Chained('object') :PathPart('read') :Args(0) :AdminRole('DNS_LOG_READ') {
    my ($self, $c) = @_;
    $c->stash({
        dns_fields => \@pf::dns_audit_log::FIELDS,
    });
    for my $field (@pf::dns_audit_log::FIELDS) {
        my $value = $c->stash->{item}{$field};
        next if !defined $value;
        $value =~ s/=2C /"\n"/ge;
        $value =~ s/=([A-Z0-9]{2})/chr(hex($1))/ge;
        $c->stash->{item}{$field} = $value;
    }
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

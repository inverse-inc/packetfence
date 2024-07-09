package pf::UnifiedApi::Controller::SecurityEvents;

=head1 NAME

pf::UnifiedApi::Controller::SecurityEvents -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::SecurityEvents

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::security_event;
use pf::fingerbank;
use pf::error qw(is_error);
use pf::UnifiedApi::Search::Builder::SecurityEvents;

has dal => 'pf::dal::security_event';
has url_param_name => 'security_event_id';
has primary_key => 'id';

has 'search_builder_class' => 'pf::UnifiedApi::Search::Builder::SecurityEvents';

sub by_mac {
    my ($self) = @_;
    my $search = $self->param('search');
    return $self->_search_by_mac($search) if pf::util::valid_mac($search);
    $self->render_error(404, $self->status_to_error_msg(404));
}

sub _search_by_mac {
    my ($self, $mac) = @_;
    my @security_events = pf::security_event::security_event_view_desc($mac);
    return $self->render(json => { items => \@security_events }) if scalar @security_events > 0 and defined($security_events[0]);
}

sub _search_by_id {
    my ($self, $id) = @_;
    my @security_event = pf::security_event::security_event_view($id);
    return $self->render(json => { items => [ $security_event[0] ] } ) if scalar @security_event > 0 and defined($security_event[0]);
}

sub _total_status {
    my ($self, $status) = @_;
    return $self->_db_execute_response(
        'SELECT COUNT(DISTINCT mac) as count from security_event where security_event.status = ?;',
        $status
    );
}

sub total_open {
    my ($self) = @_;
    return $self->_total_status('open');
}

sub total_closed {
    my ($self) = @_;
    return $self->_total_status('closed');
}

sub total_pending {
    my ($self) = @_;
    return $self->_total_status('pending');
}

sub _per_device_class_status {
    my ($self, $status) = @_;
    return $self->_db_execute_response(
        'SELECT node.device_class, COUNT(1) as count from security_event LEFT JOIN node on (node.mac=security_event.mac) WHERE security_event.status=? GROUP BY node.device_class;',
        $status
    );
}

sub _per_security_event_id_status {
    my ($self, $status) = @_;
    return $self->_db_execute_response(
        'SELECT security_event_id, COUNT(1) as count FROM security_event WHERE security_event.status=? GROUP BY security_event.security_event_id;',
        $status
    );
}

sub per_security_event_id_closed {
    my ($self) = @_;
    return $self->_per_security_event_id_status('closed');
}

sub per_security_event_id_open {
    my ($self) = @_;
    return $self->_per_security_event_id_status('open');
}

sub per_security_event_id_pending {
    my ($self) = @_;
    return $self->_per_security_event_id_status('pending');
}

sub per_device_class_open {
    my ($self) = @_;
    return $self->_per_device_class_status('open');
}

sub per_device_class_closed {
    my ($self) = @_;
    return $self->_per_device_class_status('closed');
}

sub per_device_class_pending {
    my ($self) = @_;
    return $self->_per_device_class_status('pending');
}

=head2 pre_render_create

pre_render_create

=cut

sub pre_render_create {
    my ($self, $data) = @_;
    $data->{$self->primary_key} .= "";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

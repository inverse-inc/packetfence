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

has dal => 'pf::dal::security_event';
has url_param_name => 'security_event_id';
has primary_key => 'id';

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
    return $self->render(json => undef);
}

sub _search_by_id {
    my ($self, $id) = @_;
    my @security_event = pf::security_event::security_event_view($id);
    return $self->render(json => { items => [ $security_event[0] ] } ) if scalar @security_event > 0 and defined($security_event[0]);
    return $self->render(json => undef);
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

package pf::UnifiedApi::Controller::Nodes;

=head1 NAME

pf::UnifiedApi::Controller::Nodes -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Nodes

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::Crud';
use pf::dal::node;
use pf::locationlog qw(locationlog_history_mac locationlog_view_open_mac);

has dal => 'pf::dal::node';
has id_key => 'node_id';
has primary_key => 'mac';

sub latest_locationlog_by_mac {
    my ($self) = @_;
    my $mac = $self->param('mac');
    $self->render(json => locationlog_view_open_mac($mac));
}

sub locationlog_by_mac {
    my ($self) = @_;
    my $mac = $self->param('mac');
    $self->render(json => { items => [locationlog_history_mac($mac)]});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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


package pf::UnifiedApi::Controller::Services::ClusterStatuses;

=head1 NAME

pf::UnifiedApi::Controller::Services::ClusterStatuses -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Services::ClusterStatuses

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::cluster;

sub _get_status {
    my ($self, @servers) = @_;

    my @results;
    for my $server (@servers) {
        my $client = pf::api::unifiedapiclient->new;
        $client->host($server->{management_ip});
        my $stat = $client->call("GET", "/api/v1/services/status_all", {});
        push @results, { host => $server->{host}, services => $stat->{items} };
    }

    return @results;
}

sub resource {
    my ($self) = @_;

    my $server = pf::cluster::find_server_by_hostname($self->param('server_id'));

    return 1 if defined($server);
    $self->render_error(404, { message => $self->status_to_error_msg(404) });
    return undef;
}

sub list {
    my ($self) = @_;
    $self->render(json => { items => [$self->_get_status(pf::cluster::enabled_servers)] });
}

sub get {
    my ($self) = @_;
    $self->render(json => { item => $self->_get_status(pf::cluster::find_server_by_hostname($self->param('server_id'))) });
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

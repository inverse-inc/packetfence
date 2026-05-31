package pf::UnifiedApi::Controller::Config::Connectors;

=head1 NAME

pf::UnifiedApi::Controller::Config::Connectors - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Connectors

=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::Connector';
has 'form_class' => 'pfappserver::Form::Config::Connector';
has 'primary_key' => 'connector_id';

use pf::ConfigStore::Connector;
use pfappserver::Form::Config::Connector;
use Mojo::UserAgent;
use pf::config qw(%Config);
use pf::log;

sub status {
    my ($self) = @_;
    my $logger = get_logger();

    my $config_store = $self->config_store_class->new;
    my $connectors = $config_store->readAll('id');

    my $status_map = {};
    my $url = $Config{services_url}{'pfconnector-server'};
    if ($url) {
        my $ua = Mojo::UserAgent->new;
        $ua->connect_timeout(5);
        $ua->request_timeout(5);
        my $tx = $ua->get("$url/api/v1/pfconnector/connector-status");
        if ($tx->success) {
            my $data = $tx->result->json;
            $status_map = $data->{connector_status} // {};
        } else {
            $logger->warn("Failed to fetch connector status from pfconnector-server: " . ($tx->error ? $tx->error->{message} : 'unknown error'));
        }
    } else {
        $logger->warn("Missing services_url for pfconnector-server, cannot fetch connector status");
    }

    my @items;
    foreach my $connector_id (sort keys %$connectors) {
        my $status;
        if (exists $status_map->{$connector_id}) {
            $status = $status_map->{$connector_id} ? 'up' : 'down';
        } else {
            $status = 'unknown';
        }
        push @items, { id => $connector_id, status => $status };
    }

    return $self->render(json => { items => \@items });
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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


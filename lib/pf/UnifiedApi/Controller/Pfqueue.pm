package pf::UnifiedApi::Controller::Pfqueue;

=head1 NAME

pf::UnifiedApi::Controller::Pfqueue -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Pfqueue

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::util::pfqueue qw(consumer_redis_client);
use pf::error qw(is_success is_error);
my $POLL_TIMEOUT = 30;

sub poll {
    my ($self) = @_;
    my $job_id = $self->param('job_id');
    my $redis = consumer_redis_client;
    my ($status, $response) = $self->get_job_status($job_id, $redis);
    if ((is_success($status) && $response->{status} != 202) || (is_error($status) && $status != 404 ) ) {
        return $self->render(json => $response , status => $status);
    }

    my $list_id = "$job_id-Status-Updates";
    $redis->brpop($list_id, $POLL_TIMEOUT);
    return $self->_send_status($job_id, $redis);
}

sub status {
    my ($self) = @_;
    my $job_id = $self->param('job_id');
    my $redis = consumer_redis_client;
    return $self->_send_status($job_id, $redis);
}

sub _send_status {
    my ($self, $job_id, $redis) = @_;
    my ($status, $response) = $self->get_job_status($job_id, $redis);
    return $self->render(json => $response , status => $status);
}

sub get_job_status {
    my ($self, $job_id, $redis) = @_;
    my %response = $redis->hgetall("$job_id-Status");
    if (keys %response) {
        for my $f (qw(error item)) {
            if (exists $response{$f}) {
                my $item = $response{$f};
                my ($status, $json) = $self->parse_json($item);
                if (is_success($status)) {
                    $response{$f} = $json;
                }
            }
        }
        return (200, \%response);
    }

    return (404, {});
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

package pf::api::queue;

=head1 NAME

pf::api::queue - The api queue notify

=cut

=head1 DESCRIPTION

pf::api::queue

=cut

use strict;
use warnings;
use Moo;
use pf::pfqueue::producer::redis;

=head2 queue

The queue to submit to

=cut

has queue => (
    is      => 'rw',
    default => 'general',
);

=head2 client

The queue client

=cut

has client => (
    is => 'rw',
    builder => 1,
    lazy => 1,
);

=head2 _build_client

Build the client

=cut

sub _build_client {
    my ($self) = @_;
    return pf::pfqueue::producer::redis->new;
}

=head2 call

=cut

sub call {
    my ($self) = @_;
    die "call not implemented\n";
}

=head2 notify

calls the pf api ignoring the return value

=cut

sub notify {
    my ($self, $method, @args) = @_;
    $self->client->submit($self->queue, api => [$method, @args]);
    return;
}

=head2 notify_delayed

calls the pf api ignoring the return value with a delay

=cut

sub notify_delayed {
    my ($self, $delay, $method, @args) = @_;
    $self->client->submit_delayed($self->queue, 'api', $delay, [$method, @args]);
    return;
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


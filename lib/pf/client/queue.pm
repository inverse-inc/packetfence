package pf::client::queue;

=head1 NAME

pf::client::queue add documentation

=cut

=head1 DESCRIPTION

pf::client::queue

=cut

use strict;
use warnings;
use Moo;
use Redis::Fast;
use pf::file_paths;
use List::MoreUtils qw(all);
use Sereal::Encoder qw(sereal_encode_with_object);
use pf::Sereal qw($ENCODER);

has redis => (
    is      => 'rw',
    builder => 1,
    lazy    => 1,
);

has server => (
    is       => 'rw',
    required => 1,
    default  => sub {"$install_dir/var/run/redis.sock"},
);

sub _build_redis {
    my ($self) = @_;
    my %args;
    my $server = $self->server;

    #If there is a / then consider it unix socket
    if ($server =~ m#/#) {
        $args{sock} = $server;
    }
    else {
        $args{server} = $server;
    }
    return Redis::Fast->new(%args);
}

sub submit {
    my ($self, $queue, @workers) = @_;
    if(@workers) {
        die "Not submitting a pf::worker" unless all {$_->isa("pf::worker")} @workers;
        my @encoded_data = map {sereal_encode_with_object($ENCODER, $_)} @workers;
        $self->redis->lpush($queue, @encoded_data);
    }
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

1;


package pf::accounting_events_history;

=head1 NAME

pf::provisioner

=cut

=head1 DESCRIPTION

Module to track historical accounting triggers

=cut

use Moo;
use Data::UUID;
use Time::HiRes qw(time);
use pf::Redis;
use Sort::Naturally qw(nsort);
use JSON::MaybeXS;
use pf::log;

my $UUID_GENERATOR = Data::UUID->new;


=head2 redis

The redis client to use

=cut

has redis => (
    is      => 'rw',
    builder => 1,
    lazy    => 1,
);

=head2 server

The server of the redis client

=cut

has server => (
    is       => 'rw',
    required => 1,
    default  => sub { "127.0.0.1:6379" },
);

=head2 prefix

The prefix to use when storing data in redis hashes

=cut

has prefix => (
    is      => 'rw',
    default => sub { "accounting_events_history" },
);

=head2 hash_name_prefix

The prefix to use for the hash names

=cut

sub hash_name_prefix { "data-" }

=head2 _build_redis

Build the redis client

=cut

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
    return pf::Redis->new(%args);
}

=head2 add_prefix

Add the configured prefix to a key

=cut

sub add_prefix {
    return $_[0]->prefix.":".$_[1]
}

=head2 get_new_history_hash

Get a history hash name that can be populated with new data

=cut

sub get_new_history_hash {
    my ($self) = @_;
    return $UUID_GENERATOR->create_str();
}

=head2 add_to_history_hash

Add data to an uncommited history hash

=cut

sub add_to_history_hash {
    my ($self, $hash, $mac, $tid) = @_;
    $hash = $self->add_prefix($hash);
    my $data = $self->redis->hget($hash, $mac);
    $data = $data ? decode_json($data) : {};
    $data->{$tid} = 1;
    $self->redis->hset($hash, $mac, encode_json($data));
}

=head2 commit

Commit a history hash by naming it so it can be viewed by all_history_hashes

=cut

sub commit {
    my ($self, $hash, $ttl) = @_;
    my $hash_name = $self->add_prefix($self->hash_name_prefix . time . "-$hash");
    $self->redis->rename($self->add_prefix($hash), $hash_name);
    $self->redis->expire($hash_name, $ttl);
}

=head2 all_history_hashes

List all the commited history hashes

=cut

sub all_history_hashes {
    my ($self) = @_;
    my $search = $self->add_prefix($self->hash_name_prefix)."*";
    my @histories = $self->redis->keys($search);
    @histories = nsort @histories;
    return @histories;
}

=head2 latest_history_hash

Get the name of the latest history hash

=cut

sub latest_history_hash {
    my ($self) = @_;
    my @histories = $self->all_history_hashes();
    return scalar(@histories) > 0 ? $histories[-1] : undef;
}

=head2 latest_mac_history

The the accounting triggers history for a specific MAC address

=cut

sub latest_mac_history {
    my ($self, $mac) = @_;
    my $latest = $self->latest_history_hash();

    unless(defined($latest)) {
        get_logger->warn("Unable to pull accounting history for device $mac. The history set doesn't exist yet.");
        return undef;
    }

    if($self->redis->hexists($latest, $mac)) {
        return [ keys %{decode_json($self->redis->hget($latest, $mac))} ];
    }
    else {
        return [];
    }
}

=head2 flush_all

Flush all the history hashes

=cut

sub flush_all {
    my ($self) = @_;
    my @previous = $self->all_history_hashes;
    return @previous ? $self->redis->del(@previous) : undef;
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


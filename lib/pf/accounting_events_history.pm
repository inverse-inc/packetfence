package pf::accounting_events_history;

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

has prefix => (
    is      => 'rw',
    default => sub { "accounting_events_history" },
);

sub set_name_prefix { "data-" }

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

sub add_prefix {
    return $_[0]->prefix.":".$_[1]
}

sub get_new_history_hash {
    my ($self) = @_;
    return $UUID_GENERATOR->create_str();
}

sub add_to_history_hash {
    my ($self, $hash, $mac, $tid) = @_;
    $hash = $self->add_prefix($hash);
    my $data = $self->redis->hget($hash, $mac);
    $data = $data ? decode_json($data) : {};
    $data->{$tid} = 1;
    $self->redis->hset($hash, $mac, encode_json($data));
}

#use pf::config::pfmon qw(%ConfigPfmon) ; print Dumper($ConfigPfmon{acct_maintenance}{interval})
sub commit {
    my ($self, $hash, $ttl) = @_;
    my $set_name = $self->add_prefix($self->set_name_prefix . time . "-$hash");
    $self->redis->rename($self->add_prefix($hash), $set_name);
    $self->redis->expire($set_name, $ttl);
}

sub all_history_hashes {
    my ($self) = @_;
    my $search = $self->add_prefix($self->set_name_prefix)."*";
    my @histories = $self->redis->keys($search);
    @histories = nsort @histories;
    return @histories;
}

sub latest_history_hash {
    my ($self) = @_;
    my @histories = $self->all_history_hashes();
    return scalar(@histories) > 0 ? $histories[-1] : undef;
}

sub latest_mac_history {
    my ($self, $mac) = @_;
    my $latest = $self->latest_history_hash();

    unless(defined($latest)) {
        get_logger->warn("Unable to pull accounting history for device $mac. The history set doesn't exist yet.");
        return undef;
    }

    if($self->redis->hexists($latest, $mac)) {
        return decode_json($self->redis->hget($latest, $mac));
    }
    else {
        return [];
    }
}

sub flush_all {
    my ($self) = @_;
    my @previous = $self->all_history_hashes;
    return @previous ? $self->redis->del(@previous) : undef;
}

1;


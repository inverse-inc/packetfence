package CHI::Driver::Redis;

use Moo;
use Redis;
use URI::Escape qw(uri_escape uri_unescape);
use List::MoreUtils qw(uniq);

extends 'CHI::Driver';

our $VERSION = '0.09';

has 'redis' => (
    is   => 'ro',
    lazy => 1,
    builder => '_build_redis',
);

has 'redis_options' => (
    is => 'rw',
    default => sub { {} },
);

has 'redis_class' => (
    is => 'ro',
    default => 'Redis',
);

has 'prefix'=> (
    is => 'ro',
    default => '',
);

has 'key_prefix' => (
    is => 'ro',
    builder => '_build_key_prefix',
    lazy => 1,
);

sub BUILD {
    my ($self, $params) = @_;
    foreach my $param (qw/redis redis_class redis_options prefix/) {
        if (exists $params->{$param}) {
            delete $params->{$param};
        }
    }
    my %options = (
        server => '127.0.0.1:6379',
        encoding => undef,
        %{ $self->redis_options() },
        %{ $self->non_common_constructor_params($params) },
    );
    $self->redis_options(\%options);
}

sub _build_redis {
    my ($self) = @_;
    return $self->redis_class()->new(%{ $self->redis_options() });
}

sub _build_key_prefix {
    my ($self) = @_;
    return $self->prefix.$self->namespace.'||';
}

sub fetch {
    my ($self, $key) = @_;

    my $eskey = uri_escape($key);
    my $realkey = $self->key_prefix . $eskey;
    my $val = $self->redis->get($realkey);
    return $val;
}

sub fetch_multi_hashref {
    my ($self, $keys) = @_;

    return unless scalar(@{ $keys });

    my @keys;
    foreach my $k (@$keys) {
        my $esk = uri_escape($k);
        my $key = $self->key_prefix . $esk;
        push @keys, $key;
    }

    my @vals = $self->redis->mget(@keys);

    my $count = 0;
    my %resp;
    foreach my $k (@$keys) {
        $resp{$k} = $vals[$count];
        $count++;
    }

    return \%resp;
}

sub get_keys {
    my ($self) = @_;

    my @keys = $self->_get_keys();
    my $quoted_key_prefix = quotemeta($self->key_prefix);
    @keys = map { $_ =~ s/^$quoted_key_prefix//g && $_ } @keys;

    my @unesckeys = map { uri_unescape($_) } @keys;

    return @unesckeys;
}

sub _get_keys {
    my ($self) = @_;
    my $redis = $self->redis;
    my $match = $self->key_prefix . '*';
    my @keys;
    my ($cursor, $result) = $redis->scan("0", 'match', $match);
    push @keys, @$result;
    while($cursor ne "0") {
        ($cursor, $result) = $redis->scan($cursor, 'match', $match);
        push @keys, @$result;
    }

    # SCAN can return duplicate keys
    return uniq(@keys);
}

sub get_namespaces {
    my ($self) = @_;

    return $self->redis->smembers($self->prefix . 'chinamespaces');
}

sub remove {
    my ($self, $key) = @_;

    return unless defined($key);

    my $skey = uri_escape($key);

    $self->redis->del($self->key_prefix . $skey);
}

sub store {
    my ($self, $key, $data, $expires_in) = @_;


    my $skey = uri_escape($key);
    my $realkey = $self->key_prefix . $skey;

    $self->redis->sadd($self->prefix . 'chinamespaces', $self->namespace);
    $self->redis->set($realkey, $data);

    if (defined($expires_in)) {
        $self->redis->expire($realkey, $expires_in);
    }
}

sub clear {
    my ($self) = @_;

    my @keys = $self->_get_keys();

    foreach my $k (@keys) {
        $self->redis->del($k);
    }
}

1;

__END__

=head1 NAME

CHI::Driver::Redis - Redis driver for CHI

=head1 SYNOPSIS

    use CHI;

    my $foo = CHI->new(
        driver => 'Redis',
        namespace => 'foo',
        server => '127.0.0.1:6379',
        debug => 0
    );

=head1 DESCRIPTION

A CHI driver that uses C<Redis> to store the data.  Care has been taken to
not have this module fail in fiery ways if the cache is unavailable.  It is my
hope that if it is failing and the cache is not required for your work, you
can ignore its warnings.

=head1 TECHNICAL DETAILS

=head2 Namespaces.

Redis does not have namespaces.  Therefore, we have to do some hoop-jumping.

Namespaces are tracked in a set named C<chinamespaces>.  This is a list of all
the namespaces the driver has seen.

Keys in a namespace are stored in a set that shares the name of the namespace.
The actual value is stored as "$namespace||key".

=head2 Encoding

This CHI driver uses Redis.pm.  Redis.pm by default automatically
encodes values to UTF-8.  This driver sets the Redis encoding option
to undef to disable automatic encoding.

=head1 CONSTRUCTOR OPTIONS

=over 4

=item C<redis>

option for the constructed C<Redis> object

=item C<redis_options>

for hash of options to the C<Redis> constructor

=back

Other options, including C<server>, C<debug>, and C<password> are passed to
the C<Redis> constructor.

=head1 ATTRIBUTES

=head2 redis

Contains the underlying C<Redis> object.

=head1 AUTHOR

Cory G Watson, C<< <gphat at cpan.org> >>

=head1 CONTRIBUTORS

Ian Burrell, C<< <iburrell@cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Cold Hard Code, LLC.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

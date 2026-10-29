#!/usr/bin/perl

=head1 NAME

radius_cache

=head1 DESCRIPTION

unit test for pf::connector::radius_cache: the invalidation of the RADIUS
replies cached by the remote connectors

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 19;
use Test::MockModule;
use Test::NoWarnings;

use pf::connector::radius_cache;
use pf::config qw(%Config);

# Two remote connectors on two pfconnector server instances, plus one with no
# owner (default client) and the local connector: the hooks never need the
# real servers.
my @calls;    # [ "proto:host:port", $method, $path, $data ]
{
    package Fake::Client;
    sub new { my ($class, %a) = @_; return bless {%a}, $class }
    sub proto { $_[0]{proto} }
    sub host  { $_[0]{host} }
    sub port  { $_[0]{port} }
    sub call  { my ($self, @args) = @_; die "server down\n" if $self->{die}; push @calls, [ join(":", @{$self}{qw(proto host port)}), @args ]; return {} }
}
my %clients = (
    'site-a' => Fake::Client->new(proto => 'http', host => '10.0.0.1', port => 22226),
    'site-b' => Fake::Client->new(proto => 'http', host => '10.0.0.1', port => 22226),
    'site-c' => Fake::Client->new(proto => 'http', host => '10.0.0.2', port => 22226),
);
my $factory = Test::MockModule->new('pf::factory::connector');
$factory->mock(has_remote_connectors => sub { 1 });
$factory->mock(new => sub { my ($class, $id) = @_; return exists $clients{$id} ? bless({ id => $id }, 'pf::connector') : undef });
my $store = Test::MockModule->new('pf::ConfigStore::Connector');
$store->mock(readAllIds => sub { [qw(local_connector site-a site-b site-c unknown)] });
my $connector = Test::MockModule->new('pf::connector');
$connector->mock(connectorServerApiClientWithOwnership => sub { my ($self) = @_; return ($clients{ $self->{id} }, 1) });
my @queued;
my $queue = Test::MockModule->new('pf::api::queue');
$queue->mock(new => sub { bless {}, 'pf::api::queue' });
$queue->mock(notify => sub { my ($self, @args) = @_; push @queued, [@args] });

# invalidate_now: one POST per owning server, the local connector skipped,
# the MACs cleaned and deduplicated
my $n = pf::connector::radius_cache::invalidate_now([ 'AA-BB-CC-DD-EE-01', 'aa:bb:cc:dd:ee:01', 'bogus', 'aabb.ccdd.ee02' ], reason => 'test');
is($n, 2, "two valid devices");
is(scalar @calls, 2, "one call per pfconnector server instance");
my ($one) = grep { $_->[0] eq 'http:10.0.0.1:22226' } @calls;
my ($two) = grep { $_->[0] eq 'http:10.0.0.2:22226' } @calls;
ok($one && $two, "both instances were called");
is($one->[1], 'POST', "POST");
is($one->[2], '/api/v1/pfconnector/radius-cache-invalidate', "the invalidation endpoint");
is_deeply([ sort @{ $one->[3]{connector_ids} } ], [qw(site-a site-b)], "the connectors of the first instance, grouped");
is_deeply($two->[3]{connector_ids}, [qw(site-c)], "the connector of the second instance");
is_deeply($one->[3]{macs}, [qw(aa:bb:cc:dd:ee:01 aa:bb:cc:dd:ee:02)], "MACs cleaned and deduplicated");
is(${ $one->[3]{sync} }, 0, "asynchronous by default");

# a dying server only warns, the other one is still called
@calls = ();
$clients{'site-c'}{die} = 1;
$n = pf::connector::radius_cache::invalidate_now([ 'aa:bb:cc:dd:ee:03' ], sync => 1);
is(scalar @calls, 1, "the healthy instance is still called when the other dies");
is(${ $calls[0][3]{sync} }, 1, "synchronous when asked");
delete $clients{'site-c'}{die};

# invalidate: queued, deduplicated within the window, synchronous when asked
@calls = ();
@queued = ();
is(pf::connector::radius_cache::invalidate([ 'aa:bb:cc:dd:ee:04', 'zz' ], reason => 'reevaluate_access'), 1, "one device queued");
is_deeply(\@queued, [ [ 'pfconnector_radius_cache_invalidate', macs => [ 'aa:bb:cc:dd:ee:04' ], reason => 'reevaluate_access' ] ], "the pfqueue job and its arguments");
is(pf::connector::radius_cache::invalidate([ 'aa:bb:cc:dd:ee:04' ]), 0, "the same device within the window is not queued again");
is(scalar @calls, 0, "nothing sent directly for the asynchronous requests");
is(pf::connector::radius_cache::invalidate([ 'aa:bb:cc:dd:ee:04' ], sync => 1), 1, "synchronous: sent now, even within the window");
is(scalar @calls, 2, "... to both instances");

# nothing happens without remote connectors
$factory->mock(has_remote_connectors => sub { 0 });
@queued = ();
is(pf::connector::radius_cache::invalidate([ 'aa:bb:cc:dd:ee:05' ]), 0, "no remote connector: no job");

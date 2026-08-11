package pf::connector;

use Moo;
use URI;
use pf::api::unifiedapiclient;
use pf::AtFork;
use pf::config qw(%Config);
use pf::log;
use pf::util qw(isenabled);

has id => (is => 'rw');

has secret => (is => 'rw');

has networks => (is => 'rw');

has fingerbank_environment => (is => 'rw');

my %connections;
my $redis;
my %dynreverse_cache;
sub CLONE {
    %connections = ();
    %dynreverse_cache = ();
    $redis = undef;
}
pf::AtFork->add_to_child(\&CLONE);
CLONE();

sub connect_redis {
    if($redis) {
        return $redis;
    }
    else {
        $redis = pf::Redis->new(server => $Config{pfconnector}{redis_server});
        return $redis;
    }
}

sub connectorServerApiClient {
    my ($self) = @_;
    #TODO: get this out of redis_queue
    my $redis = $self->connect_redis;
    if(my $server = $redis->get($Config{pfconnector}{redis_tunnels_namespace}.$self->id)) {
        if(exists($connections{$server})) {
            return $connections{$server};
        }
        my $uri = URI->new($server);
        $connections{$server} = pf::api::unifiedapiclient->new(proto => $uri->scheme, host => $uri->host, port => $uri->port);
        return $connections{$server};
    }
    else {
        return pf::api::unifiedapiclient->default_client;
    }
}

# The TTL must stay at or below the server's LAST_TOUCHED_TIMEOUT (10s): the
# dynreverse API call is what refreshes the tunnel's LastTouched, so a longer
# client-side TTL could let an idle tunnel be reaped while its port is still
# being served from this cache.
our $DYNREVERSE_CACHE_TTL = 10;

sub dynreverse {
    my ($self, $to, $opts) = @_;
    $opts //= {};

    # Hot paths (SNMP/CoA on every RADIUS request when *UseConnector is
    # enabled) call this per packet; serve the port from a short per-process
    # cache instead of POSTing to the pfconnector server every time.
    # pod_direct connections (rare, long-lived, e.g. domain join) bypass the
    # cache since their host depends on which server instance answers.
    my $cache_key = $self->id . ":" . $to;
    if (!$opts->{pod_direct}) {
        my $entry = $dynreverse_cache{$cache_key};
        if ($entry && $entry->{expires_at} > time) {
            return { %{$entry->{conn}} };
        }
    }

    my $client = $self->connectorServerApiClient;
    my $connector_conn = $client->call("POST", "/api/v1/pfconnector/dynreverse", {
        to => $to,
        connector_id => $self->id,
    });

    #Override the host value returned by the connector server's dynreverse API.
    #pod_direct: dial the exact pfconnector instance that owns this tunnel instead of
    #the k8s Service ClusterIP. A freshly-bound dynreverse port isn't reliably routed
    #by kube-proxy through the ClusterIP (the static tunnels work only because they've
    #been programmed for a while), whereas the instance address we just used for this
    #API call is directly reachable. Required for long-lived calls like the domain join
    #where dialing the ClusterIP hangs and the tunnel gets reaped mid-request.
    #In K8S/SaaS the connector is otherwise reached through PFCONNECTOR_SERVICE_HOST; the
    #host the server returns (e.g. containers-gateway.internal) doesn't resolve from this
    #pod, so whenever PFCONNECTOR_SERVICE_HOST is defined we prefer it.
    #Otherwise, on a 'Classic PF' container, force the local containers interface so that
    #the docker proxy gets the packets back on the containers network.
    if ($opts->{pod_direct}) {
        $connector_conn->{host} = $client->host;
    }
    elsif ($ENV{PFCONNECTOR_SERVICE_HOST}) {
        $connector_conn->{host} = $ENV{PFCONNECTOR_SERVICE_HOST};
    }
    elsif ( ($ENV{IS_A_CLASSIC_PF_CONTAINER} && !$ENV{DOCKER_NETWORK_IS_HOST}) || (exists $ENV{PF_SAAS} && !isenabled($ENV{PF_SAAS})) ) {
        $connector_conn->{host} = "containers-gateway.internal";
    }
    
    get_logger->debug("Using pfconnector dynreverse ".$connector_conn->{host}.":".$connector_conn->{port}." via ".$self->id);

    if (!$opts->{pod_direct}) {
        # Store and return copies so a caller mutating the result can't poison the cache.
        $dynreverse_cache{$cache_key} = { conn => { %$connector_conn }, expires_at => time + $DYNREVERSE_CACHE_TTL };
    }

    return $connector_conn;
}

=head2 reprovision_static

Ask the pfconnector server to (re)provision this connector's static reverse
tunnels on its already-connected tunnel, so tunnels added since the connector
last handshaked (e.g. the NTLM-auth tunnel of a freshly-committed domain) become
usable without a manual connector reconnect. Best-effort: logs and swallows
errors (a disconnected connector will pick everything up on its next connect).

=cut

sub reprovision_static {
    my ($self) = @_;
    eval {
        $self->connectorServerApiClient->call("POST", "/api/v1/pfconnector/reprovision-static-connections", {
            connector_id => $self->id,
        });
    };
    if ($@) {
        get_logger->warn("Failed to reprovision static connections for connector '".$self->id."': $@");
    }
    return;
}

1;


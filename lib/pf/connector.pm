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
    my ($client) = $self->connectorServerApiClientWithOwnership;
    return $client;
}

# Same as connectorServerApiClient but also reports whether the client points at
# the pfconnector server instance that actually holds this connector's tunnel
# (the address it registered in Redis when it connected) rather than at the
# generic unified API client.
sub connectorServerApiClientWithOwnership {
    my ($self) = @_;
    #TODO: get this out of redis_queue
    my $redis = $self->connect_redis;
    if(my $server = $redis->get($Config{pfconnector}{redis_tunnels_namespace}.$self->id)) {
        if(exists($connections{$server})) {
            return ($connections{$server}, 1);
        }
        my $uri = URI->new($server);
        $connections{$server} = pf::api::unifiedapiclient->new(proto => $uri->scheme, host => $uri->host, port => $uri->port);
        return ($connections{$server}, 1);
    }
    else {
        return (pf::api::unifiedapiclient->default_client, 0);
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

    my ($client, $owns_tunnel) = $self->connectorServerApiClientWithOwnership;
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
    if ($opts->{pod_direct}) {
        $connector_conn->{host} = $client->host;
    }
    else {
        $connector_conn->{host} = reverse_host($connector_conn->{host}, $client, $owns_tunnel);
    }
    
    get_logger->debug("Using pfconnector dynreverse ".$connector_conn->{host}.":".$connector_conn->{port}." via ".$self->id);

    if (!$opts->{pod_direct}) {
        # Store and return copies so a caller mutating the result can't poison the cache.
        $dynreverse_cache{$cache_key} = { conn => { %$connector_conn }, expires_at => time + $DYNREVERSE_CACHE_TTL };
    }

    return $connector_conn;
}

=head2 reverse_host

The host to dial for a reverse port that the pfconnector server bound on its side of
a connector's tunnel (a dynreverse port or the connector's fingerbank collector port),
given the host the server returned, the API client used to reach that server and
whether that client points at the instance owning the tunnel.

=cut

sub reverse_host {
    my ($host, $client, $owns_tunnel) = @_;

    #In K8S/SaaS the connector is reached through PFCONNECTOR_SERVICE_HOST; the
    #host the server returns (e.g. containers-gateway.internal) doesn't resolve from this
    #pod, so whenever PFCONNECTOR_SERVICE_HOST is defined we prefer it.
    if ($ENV{PFCONNECTOR_SERVICE_HOST}) {
        #A dynamic reverse port is bound on the single pfconnector instance that owns the
        #tunnel and, unlike the static connections, it is never published on the
        #pfconnector k8s Service. Sending to the Service ClusterIP on such a port has
        #no kube-proxy rule behind it, so the packets are silently dropped: RADIUS
        #CoA/Disconnect and SNMP going through a connector simply time out and nothing
        #ever reaches the connector. Dial the owning instance directly when we know it.
        return $owns_tunnel ? $client->host : $ENV{PFCONNECTOR_SERVICE_HOST};
    }

    #On a 'Classic PF' container, force the local containers interface so that
    #the docker proxy gets the packets back on the containers network.
    if ( ($ENV{IS_A_CLASSIC_PF_CONTAINER} && !$ENV{DOCKER_NETWORK_IS_HOST}) || (exists $ENV{PF_SAAS} && !isenabled($ENV{PF_SAAS})) ) {
        return "containers-gateway.internal";
    }

    return $host;
}

=head2 fingerbank_collector_endpoint

The fingerbank collector co-located with this connector, as a URI pointing at the
reverse port the pfconnector server bound for it. Dies when the server has no active
remote tunnel for this connector.

=cut

sub fingerbank_collector_endpoint {
    my ($self) = @_;
    my ($client, $owns_tunnel) = $self->connectorServerApiClientWithOwnership;
    my $res = $client->call("GET", "/api/v1/pfconnector/fingerbank-collector-endpoint?connector-id=".$self->id, undef);
    die "No fingerbank collector endpoint returned for connector ".$self->id."\n" unless $res && $res->{endpoint};

    my $uri = URI->new($res->{endpoint});
    $uri->host(reverse_host($uri->host, $client, $owns_tunnel));
    return $uri;
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

=head2 radius_cache_invalidate

Ask the pfconnector server holding this connector's tunnel to make the
connector-remote drop the cached RADIUS replies of the given devices (see
pf::connector::radius_cache for the broadcast every hook uses).

=cut

sub radius_cache_invalidate {
    my ($self, $macs, %opts) = @_;
    eval {
        $self->connectorServerApiClient->call("POST", "/api/v1/pfconnector/radius-cache-invalidate", {
            connector_ids => [$self->id],
            macs          => $macs,
            sync          => $opts{sync} ? \1 : \0,
        });
    };
    if ($@) {
        get_logger->warn("Failed to ask connector '".$self->id."' to drop cached RADIUS replies: $@");
    }
    return;
}

1;

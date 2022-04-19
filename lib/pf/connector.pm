package pf::connector;

use Moo;
use URI;
use pf::api::unifiedapiclient;
use pf::config::pfqueue;
use pf::pfqueue::consumer::redis;
use POSIX::AtFork;

has id => (is => 'rw');

has secret => (is => 'rw');

has networks => (is => 'rw');

my %connections;
sub CLONE {
    %connections = ();
}
POSIX::AtFork->add_to_child(\&CLONE);
CLONE();


sub connectorServerApiClient {
    my ($self) = @_;
    #TODO: get this out of redis_queue
    my $redis = pf::pfqueue::consumer::redis->new({ %{$ConfigPfqueue{"consumer"}} })->redis;
    if(my $server = $redis->get("pfconnector:activeTunnels:".$self->id)) {
        if(exists($connections{$server})) {
            print "from hash \n";
            return $connections{$server};
        }
        #TODO: get connections to be reused
        my $uri = URI->new($server);
        $connections{$server} = pf::api::unifiedapiclient->new(proto => $uri->scheme, host => $uri->host, port => $uri->port);
        return $connections{$server};
    }
    else {
        return pf::api::unifiedapiclient->management_client;
    }
}

sub dynreverse {
    my ($self, $to) = @_;
    my $connector_conn = $self->connectorServerApiClient->call("POST", "/api/v1/pfconnector/dynreverse", {
        to => $to,
        connector_id => $self->id,
    });
    return $connector_conn;
}

1;


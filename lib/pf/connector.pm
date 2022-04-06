package pf::connector;

use Moo;

has id => (is => 'rw');

has secret => (is => 'rw');

has networks => (is => 'rw');

sub dynreverse {
    my ($self, $to) = @_;
    #TODO: implement reverse forwards reuse here or in pfconnector
    my $connector_conn = pf::api::unifiedapiclient->management_client->call("POST", "/api/v1/pfconnector/dynreverse", {
        to => $to,
        connector_id => $self->id,
    });
    return $connector_conn;
}

1;


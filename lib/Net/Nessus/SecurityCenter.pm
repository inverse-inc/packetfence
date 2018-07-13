package Net::Nessus::SecurityCenter;

use warnings;
use strict;

use Carp;
use LWP::UserAgent;
use JSON;
use List::Util qw(first);

sub new {
    my ($class, %params) = @_;

    my $url   = $params{url} || 'https://localhost:8834/';
    my $agent = LWP::UserAgent->new();

    $agent->timeout($params{timeout})
        if $params{timeout};
    $agent->ssl_opts(%{$params{ssl_opts}})
        if $params{ssl_opts} && ref $params{ssl_opts} eq 'HASH';

    $agent->cookie_jar({ file => "/tmp/.securitycenter.cookies.txt" });
    my $self = {
        url   => $url,
        agent => $agent
    };
    bless $self, $class;

    return $self;
}

sub create_session {
    my ($self, %params) = @_;
    my $result = $self->_post("/token", %params);
    $self->{agent}->default_header('X-SecurityCenter' => "$result->{'response'}->{token}");
}

sub destroy_session {
    my ($self, %params) = @_;

    $self->{agent}->delete($self->{url} . '/session');
}

sub list_policies {
    my ($self) = @_;

    my $result = $self->_get('/policy');
    return $result->{response}->{usable} ? @{$result->{response}->{usable}} : ();
}

sub get_policy_id {
    my ($self, %params) = @_;
    croak "missing name parameter" unless $params{name};

    my $policy = first { $_->{name} eq $params{name} } $self->list_policies();
    return unless $policy;

    return $policy->{id};

}

sub list_repository {
    my ($self) = @_;
    my $result = $self->_get('/repository');

    return $result->{response} ? @{$result->{response}} : ();

}

sub get_repository_id {
    my ($self, %params) = @_;
    croak "missing name parameter" unless $params{name};

    my $repository = first { $_->{name} eq $params{name} } $self->list_repository();
    return unless $repository;

    return $repository->{id};
}

sub download_report {
    my ($self, %params) = @_;
    my $scan_id = delete $params{scan_id};
    my $result = $self->_post_download("/scanResult/".$scan_id."/download", %params);
    return $result;
}

sub create_scan {
    my ($self, %params) = @_;

    my $result = $self->_post("/scan", %params);
    return $result->{response}->{id};
}

sub configure_scan {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};
    croak "missing uuid parameter" unless $params{uuid};
    croak "missing settings parameter" unless $params{settings};

    my $scan_id = delete $params{scan_id};

    my $result = $self->_put("/scans/$scan_id", %params);
    return $result;
}

sub delete_scan {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};

    my $scan_id = delete $params{scan_id};

    my $result = $self->_delete("/scans/$scan_id");
    return 1;
}

sub get_scan_details {
    my ($self, %params) = @_;

    my $result = $self->_get("/scanResult");
    return $result->{response}->{usable};
}

sub get_scan_id {
    my ($self, %params) = @_;

    croak "missing name parameter" unless $params{scan_id};

    my $scan =
        first { $_->{description} eq $params{scan_id} } @{$self->get_scan_details()};
    return unless $scan;

    return $scan->{id};
}

sub get_scan_status {
    my ($self, %params) = @_;

    croak "missing scan_id parameter" unless $params{scan_id};

    my $details = first { $_->{description} eq $params{scan_id} } @{$self->get_scan_details()};
    return $details->{status};
}

sub _get {
    my ($self, $path, %params) = @_;

    my $url = URI->new($self->{url} . '/rest' . $path);
    $url->query_form(%params);

    my $response = $self->{agent}->get($url);

    my $result = eval { from_json($response->content()) };
    if ($response->is_success()) {
        return $result;
    } else {
        if ($result) {
            croak "server error: " . $result->{error};
        } else {
            croak "communication error: " . $response->message()
        }
    }
}

sub _delete {
    my ($self, $path) = @_;

    my $response = $self->{agent}->delete($self->{url} . $path);

    my $result = eval { from_json($response->content()) };

    if ($response->is_success()) {
        return $result;
    } else {
        if ($result) {
            croak "server error: " . $result->{error};
        } else {
            croak "communication error: " . $response->message()
        }
    }
}

sub _post {
    my ($self, $path, %params) = @_;

    my $content = to_json(\%params);

    my $response = $self->{agent}->post(
        $self->{url} . '/rest' . $path,
        'Content-Type' => 'application/json',
        'Content'      => $content
    );

    my $result = eval { from_json($response->content()) };

    if ($response->is_success()) {
        return $result;
    } else {
        if ($result) {
            croak "server error: " . $result->{error};
        } else {
            croak "communication error: " . $response->message()
        }
    }
}

sub _post_download {
    my ($self, $path, %params) = @_;

    my $content = to_json(\%params);

    my $response = $self->{agent}->post(
        $self->{url} . '/rest' . $path,
        'Content-Type' => 'application/json',
        'Content'      => $content
    );

    my $result = eval { from_json($response->content()) };

    if ($response->is_success()) {
        return $response->content();
    } else {
        if ($result) {
            croak "server error: " . $result->{error};
        } else {
            croak "communication error: " . $response->message()
        }
    }
}

sub _post_file {
    my ($self, $path, $file) = @_;

    my $response = $self->{agent}->post(
        $self->{url} . '/rest'. $path,
        'Content-Type' => 'multipart/form-data',
        'Content'      => [
			Filedata => [$file]
		]
    );

    my $result = eval { from_json($response->content()) };

    if ($response->is_success()) {
        return $result;
    } else {
        if ($result) {
            croak "server error: " . $result->{error};
        } else {
            croak "communication error: " . $response->message()
        }
    }
}

sub _put {
    my ($self, $path, %params) = @_;

    my $content = to_json(\%params);

    my $response = $self->{agent}->put(
        $self->{url} . '/rest'. $path,
        'Content-Type' => 'application/json',
        'Content'      => $content
    );

    my $result = eval { from_json($response->content()) };

    if ($response->is_success()) {
        return $result;
    } else {
        if ($result) {
            croak "server error: " . $result->{error};
        } else {
            croak "communication error: " . $response->message()
        }
    }
}

sub DESTROY {
    my ($self) = @_;
    $self->destroy_session() if $self->{agent}->default_header('X-SecurityCenter');
}

1;

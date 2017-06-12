package pf::multi_cluster::flansible;

use strict;
use warnings;

use pf::file_paths qw(
    $ansible_dir
);
use pf::log;
use LWP::UserAgent;
use JSON;

our $FLANSIBLE_API_HOST = "localhost";
our $FLANSIBLE_API_PORT = "3000";

sub lwp_client {
    my $ua = LWP::UserAgent->new;
    # TODO: make this constants or configurable
    $ua->credentials("$FLANSIBLE_API_HOST:$FLANSIBLE_API_PORT", "Authentication Required", "admin", "admin");
    return $ua;
}

sub play {
    my ($playbook, $scope) = @_;

    my $ua = lwp_client();
    my $req = HTTP::Request->new(POST => "http://$FLANSIBLE_API_HOST:$FLANSIBLE_API_PORT/api/ansibleplaybook");
    $req->content_type('application/json');
    $req->content(encode_json({
        playbook_dir => $ansible_dir, 
        playbook => "packetfence-$playbook.yml", 
        extra_vars => {target => $scope},
    }));

    my $res = $ua->request($req);

    if($res->is_success) {
        get_logger->info("Successfully started playing $playbook for scope $scope");
        return decode_json($res->content)->{task_id};
    }
    else {
        die $res->status_line;
    }
}

sub playStatus {
    my ($task_id) = @_;

    my $ua = lwp_client();
    my $req = HTTP::Request->new(GET => "http://$FLANSIBLE_API_HOST:$FLANSIBLE_API_PORT/api/ansibletaskstatus/$task_id");
    my $res = $ua->request($req);

    if($res->is_success) {
        get_logger->info("Successfully fetched job status for $task_id");
        return decode_json($res->content);
    }
    else {
        die $res->status_line;
    }
}

sub playOutput {
    my ($task_id) = @_;

    my $ua = lwp_client();
    my $req = HTTP::Request->new(GET => "http://$FLANSIBLE_API_HOST:$FLANSIBLE_API_PORT/api/ansibletaskoutput/$task_id");
    my $res = $ua->request($req);

    if($res->is_success) {
        get_logger->info("Successfully fetched job output for $task_id");
        return $res->content;
    }
    else {
        die $res->status_line;
    }
}

1;

package pf::multi_cluster::flansible;

use strict;
use warnings;

use pf::file_paths qw(
    $ansible_dir
);
use pf::log;
use LWP::UserAgent;
use JSON;
use pf::Redis;

our $FLANSIBLE_API_HOST = "localhost";
our $FLANSIBLE_API_PORT = "3000";

our $FLANSIBLE_REDIS_HOST = "localhost";
our $FLANSIBLE_REDIS_PORT = "6379";

our $TASK_EXPIRATION = 86400;

our $STARTED_KEY_PREFIX = "play-started-";

sub redis_client {
    return pf::Redis->new(server => "$FLANSIBLE_REDIS_HOST:$FLANSIBLE_REDIS_PORT");
}

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
        my $task_id = decode_json($res->content)->{task_id};
        my $key = $STARTED_KEY_PREFIX.$task_id;
        redis_client->setex($key, $TASK_EXPIRATION, encode_json({playbook => $playbook, scope => $scope, started_at => time}));
        return $task_id;
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

sub listTasks {
    my @keys = redis_client->keys('*');
    my %task_ids;
    for my $key (@keys) {
        if($key =~ /^play-started-(.*)/) {
            $task_ids{$1} = decode_json(redis_client->get($key));
        }
    }
    # Sort them by value which is the started time and put them in an array
    my @ordered_tasks = map { 
        { task_id => $_, %{$task_ids{$_}} } 
    } sort { $task_ids{$b}{started_at} <=> $task_ids{$a}{started_at} } keys %task_ids;

    return \@ordered_tasks;
}

1;

package pf::acls_push;

=head1 NAME

pf::acls_push - module to trigger an ansible task to push the acls on the equipment.

=cut

=head1 DESCRIPTION

pf::acls_push contains the functions necessary to configure semaphore to create and execute
a task to write acls directly on the equipement.

=cut

use strict;
use warnings;

use Moo;

use WWW::Curl::Easy;
use pf::Curl;
use JSON::MaybeXS qw( decode_json encode_json is_bool );
use pf::config qw(
    %Config
);
use pf::log;
use pf::file_paths qw(
    $var_dir
);
use pf::constants qw($TRUE $FALSE);
use Data::Dumper;

=head1 Atrributes

=cut

=head2 username

Username of a user that has the API rights

=cut

has username => (is => 'rw', default => sub { $Config{'database'}{'user'} } );

=head2 password

Password of a user who has the API rights

=cut

has password => (is => 'rw', default => sub { $Config{'database'}{'pass'} } );

=head2 host

Host of semaphore

=cut

has host => (is => 'rw', default => sub { "127.0.0.1" } );

=head2 protocol

Protocol to connect to the web API

=cut

has protocol => (is => 'rw', default => sub { "http" } );

=head2 port

Port of the Semaphore api

=cut

has port => (is => 'rw', default => sub { 3000 });

=head2 access_token

The access token to be authorized on the Semaphore web API

=cut

has access_token => (is => 'rw');

=head2 switch_id

The SwitchID where PacketFence will push acl


=cut

has switch_id => (is => 'rw');

=head2 profect_id

The project_id returned ny semaphore

=cut

has project_id => (is => 'rw');


=head2 fetch_token

Fetch the authentication token on the Semaphore

=cut

sub fetch_token {
    my ($self) = @_;
    my $logger = get_logger();

    my $res = $self->_do_post("login", encode_json({ auth => $self->username, password => $self->password}));

    if($res->is_success){
        $res = $self->_do_post("tokens");
	my $info = decode_json($res->decoded_content);
        my $token = $info->{id};
        $logger->debug("Got token : $token");
	$self->access_token($token);
        return $token;
    }
    else {
        $logger->error("Failed to get token from Semaphore API : ".$res->status_line);
        return undef;
    }
}

sub push_acls {
    my ($self, $switchID) = @_;
    my $logger = get_logger();
    $self->switch_id($switchID);
    $self->fetch_token();
    $self->createProject();
    $self->createAccessKey();
    $self->createRepository();
    $self->createEnv();
    $self->createInventory();
    $self->createTemplate();
    $self->launchTask();



}

sub createProject {
    my ($self) = @_;
    my $logger = get_logger();
    my $content = encode_json({name => "Switch_".$self->switch_id, alert => is_bool($FALSE)});
    my $res = $self->_do_post("projects", $content);
    if($res->is_success) {
        my $info = decode_json($res->decoded_content);
        my $id = $info->{id};
        $logger->debug("Got project_id : $id");
        $self->project_id($id);
    } else {
        $logger->warn(Dumper $res);
    }
}

sub createAccessKey {
    my ($self) = @_;
    my $logger = get_logger();
    my $content = encode_json({name => "none", type => "none", project_id => $self->project_id});
    my $res = $self->_do_post("accesskeys", $content);
    if($res->is_success) {
       $logger->warn(Dumper $res); 
    } else {
       $logger->warn(Dumper $res);
    }
}


sub createRepository {
    my ($self) = @_;
    my $logger = get_logger();
    my $switch_id_path = $self->switch_id;
    $switch_id_path =~ s/\./_/g;
    # TODO Get the ssh_key_id from a api call
    my $content = encode_json({name => "Ansible_Switch_".$self->switch_id, project_id => $self->project_id, ssh_key_id => 1, git_url => "/opt/semaphore/$switch_id_path"});
    my $res = $self->_do_post("repository", $content);
    if($res->is_success) {
        $logger->warn(Dumper $res);
    } else {
        $logger->warn(Dumper $res);
    }
}

sub createEnv {
    my ($self) = @_;
    my $logger = get_logger();
    my $switch_id_path = $self->switch_id;
    $switch_id_path =~ s/\./_/g;
    my $env_content = encode_json({inventory => "inventory.yml", host_key_checking => "False", timeout => "10", nocows => "1", deprecation_warnings => "False", retry_files_enabled => "False", log_path => "./ansible.log", forks => "10", collections_path => "/opt/semaphore/$switch_id_path/collections/"});
    my $json_content = encode_json({});
    my $content = encode_json({json => $json_content, env => $env_content, project_id => $self->project_id, name => "Switch_ENV_".$self->switch_id});
    my $res = $self->_do_post("environment", $content);
    if($res->is_success) {
        $logger->warn(Dumper $res);
    } else {
        $logger->warn(Dumper $res);
    }
}

sub createInventory {
    my ($self) = @_;
    my $logger = get_logger();
    my $switch_id_path = $self->switch_id;
    $switch_id_path =~ s/\./_/g;
    # TODO Get the ssh_key_id from a api call
    my $content = encode_json({name => "Switch_INV_".$self->switch_id, project_id => $self->project_id, ssh_key_id => 1, type => "file", inventory => "inventory.yml"});
    my $res = $self->_do_post("inventory", $content);
    if($res->is_success) {
        $logger->warn(Dumper $res);
    } else {
        $logger->warn(Dumper $res);
    }
}

sub createTemplate {
    my ($self) = @_;
    my $logger = get_logger();
    my $switch_id_path = $self->switch_id;
    $switch_id_path =~ s/\./_/g;
    # TODO Get the ssh_key_id and the repository_id from a api call
    my $content = encode_json({name => "Switch_ACLS_".$self->switch_id, playbook => "switch_acls.yml", inventory_id => 1, repository_id => 1, environment_id => 1, project_id => $self->project_id, type => ""});
    my $res = $self->_do_post("templates", $content);
    if($res->is_success) {
        $logger->warn(Dumper $res);
    } else {
        $logger->warn(Dumper $res);
    }
}

sub launchTask {
    my ($self) = @_;
    my $logger = get_logger();
    my $switch_id_path = $self->switch_id;
    $switch_id_path =~ s/\./_/g;
    # TODO Get the template_id a api call
    my $content = encode_json({template_id => "2"});
    my $res = $self->_do_post("tasks", $content);
    if($res->is_success) {
        $logger->warn(Dumper $res);
    } else {
        $logger->warn(Dumper $res);
    }
}

=head2 _execute_request

Execute a request on the Semaphore API

=cut

sub _execute_request {
    my ($self, $req) = @_;
    $req->header("Authorization", "Bearer ".$self->access_token) if (defined($self->access_token) && $self->access_token ne "");
    my $ua = LWP::UserAgent->new();
    $ua->cookie_jar({ file => "$var_dir/run/.semaphore.cookies.txt", autosave => 1, ignore_discard => 1});
    return $ua->request($req);
}

=head2 _do_post

Execute a POST request on the Semaphore API

=cut

sub _do_post {
    my ($self, $uri, $content) = @_;
    if (defined($content)) {
        return $self->_execute_request(HTTP::Request::Common::POST($self->_build_uri($uri), Content => $content, 'Content-Type' => 'application/json'));
    } else {
        return $self->_execute_request(HTTP::Request::Common::POST($self->_build_uri($uri), 'Content-Type' => 'application/json'));
    }
}



=head2 _do_get

Execute a GET request on the Semaphore API

=cut

sub _do_get {
    my ($self, $uri) = @_;
    return $self->_execute_request(HTTP::Request::Common::GET($self->_build_uri($uri)));
}

=head2 _build_uri

Build the API URI based on the configuration

=cut

sub _build_uri {
    my ($self, $type) = @_;
    my $project_id = 1;
    if (defined($self->project_id)) {
        $project_id = $self->project_id;
    }
    my $URIS = {
        login => "/api/auth/login",
        tokens => "/api/user/tokens",
        projects => "/api/projects",
        accesskeys => "/api/project/".$project_id."/keys",
        repository => "/api/project/".$project_id."/repositories",
        environment => "/api/project/".$project_id."/environment",
        inventory => "/api/project/".$project_id."/inventory",
        templates => "/api/project/".$project_id."/templates",
        tasks => "/api/project/".$project_id."/tasks",
    };
    my $path = $URIS->{$type};
    get_logger->warn($path);
    return $self->protocol."://".$self->host.":".$self->port."$path";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;


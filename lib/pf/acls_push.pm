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

The project_id returned by semaphore

=cut

has project_id => (is => 'rw');

=head2 key_id

The key_id created on semaphore

=cut

has key_id => (is => 'rw');

=head2 inentory_id

The inventory_id created on semaphore

=cut

has inventory_id => (is => 'rw');

=head2 template_id

The template_id created on semaphore

=cut

has template_id => (is => 'rw');


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
        return $TRUE;
    }
    else {
        $logger->error("Failed to get token from Semaphore API : ".$res->status_line);
        return $FALSE;
    }
}

sub push_acls {
    my ($self, $switchID) = @_;
    my $logger = get_logger();
    $self->switch_id($switchID);
    my $error = $self->fetch_token();
    return if (!$error);
    $error = $self->cleanProject();
    return if (!$error);
    $error = $self->createProject();
    return if (!$error);
    $error = $self->createAccessKey();
    return if (!$error);
    $error = $self->getAccessKey();
    return if (!$error);
    $error = $self->createRepository();
    return if (!$error);
    $error = $self->createEnv();
    return if (!$error);
    $error = $self->createInventory();
    return if (!$error);
    $error = $self->getInventory();
    return if (!$error);
    $error = $self->createTemplate();
    return if (!$error);
    $error = $self->getTemplate();
    return if (!$error);
    $error = $self->launchTask();
    return if (!$error);
    $error = $self->logout();
    return if (!$error);
}

sub cleanProject {
    my ($self) = @_;
    my $logger = get_logger();
    my $res = $self->_do_get("projects");
    if($res->is_success) {
        my $info = decode_json($res->decoded_content);
        foreach my $entry ( @{$info} ) {
            if ($entry->{name} eq "Switch_".$self->switch_id) {
                $self->project_id($entry->{id});
                $res = $self->_do_delete("deleteproject");
                if($res->is_success) {
                    $logger->info("Project Switch_".$self->switch_id." has been cleaned");
                } else {
                    $logger->error("Project Switch_".$self->switch_id." has not been cleaned");
                    return $FALSE;
                }
            }
        }
        return $TRUE;
    } else {
       $logger->error("Not able to get the semaphore projects");
       return $TRUE;
    }
}

sub createProject {
    my ($self) = @_;
    my $logger = get_logger();
    my $content = encode_json({name => "Switch_".$self->switch_id, alert => is_bool($FALSE)});
    my $res = $self->_do_post("projects", $content);
    if($res->is_success) {
        my $info = decode_json($res->decoded_content);
        my $id = $info->{id};
        $logger->info("Successfully created project Switch_".$self->switch_id);
        $self->project_id($id);
        return $TRUE;
    } else {
        $logger->error("Not able to create a project");
        return $FALSE;
    }
}

sub createAccessKey {
    my ($self) = @_;
    my $logger = get_logger();
    my $content = encode_json({name => "none", type => "none", project_id => $self->project_id});
    my $res = $self->_do_post("accesskeys", $content);
    if($res->is_success) {
        $logger->info("Access Key none has been created");
        return $TRUE;
    } else {
        $logger->error("Access Key not created");
        return $FALSE;
    }
}

sub getAccessKey {
    my ($self) = @_;
    my $logger = get_logger();
    my $res = $self->_do_get("accesskeys");
    if($res->is_success) {
        my $info = decode_json($res->decoded_content);
        foreach my $entry ( @{$info} ) {
            if ($entry->{name} eq 'none') {
                $self->key_id($entry->{id});
                $logger->info("Access ID retrieved successfully: ".$self->key_id);
                return $TRUE;
            }
        }
    } else {
       $logger->error("Access ID not retrieved successfully");
       return $FALSE;
    }
}

sub createRepository {
    my ($self) = @_;
    my $logger = get_logger();
    my $switch_id_path = $self->switch_id;
    $switch_id_path =~ s/\./_/g;
    my $content = encode_json({name => "Ansible_Switch_".$self->switch_id, project_id => $self->project_id, ssh_key_id => $self->key_id, git_url => "/opt/semaphore/$switch_id_path"});
    my $res = $self->_do_post("repository", $content);
    if($res->is_success) {
        $logger->info("Repository Ansible_Switch_".$self->switch_id." created successfully");
        return $TRUE;
    } else {
        $logger->error("Repository Ansible_Switch_".$self->switch_id." not created successfully");
        return $FALSE;
    }
}

sub createEnv {
    my ($self) = @_;
    my $logger = get_logger();
    my $switch_id_path = $self->switch_id;
    $switch_id_path =~ s/\./_/g;
    my $env_content = encode_json({inventory => "inventory.yml", host_key_checking => "False", timeout => "10", nocows => "1", deprecation_warnings => "False", retry_files_enabled => "False", forks => "10", collections_path => "/opt/semaphore/$switch_id_path/collections/"});
    my $json_content = encode_json({});
    my $content = encode_json({json => $json_content, env => $env_content, project_id => $self->project_id, name => "Switch_ENV_".$self->switch_id});
    my $res = $self->_do_post("environment", $content);
    if($res->is_success) {
        $logger->info("Environment Switch_ENV_".$self->switch_id." created successfully");
        return $TRUE;
    } else {
        $logger->error("Environment Switch_ENV_".$self->switch_id." not created successfully");
        return $FALSE;
    }
}

sub createInventory {
    my ($self) = @_;
    my $logger = get_logger();
    my $switch_id_path = $self->switch_id;
    $switch_id_path =~ s/\./_/g;
    my $content = encode_json({name => "Switch_INV_".$self->switch_id, project_id => $self->project_id, ssh_key_id => $self->key_id, type => "file", inventory => "inventory.yml"});
    my $res = $self->_do_post("inventory", $content);
    if($res->is_success) {
        $logger->info("Inventory Switch_INV_".$self->switch_id." created successfully");
        return $TRUE;
    } else {
        $logger->error("Inventory Switch_INV_".$self->switch_id." not created successfully");
        return $FALSE;
    }
}

sub getInventory {
    my ($self) = @_;
    my $logger = get_logger();
    my $res = $self->_do_get("inventory");
    if($res->is_success) {
        my $info = decode_json($res->decoded_content);
        foreach my $entry ( @{$info} ) {
            if ($entry->{name} eq "Switch_INV_".$self->switch_id) {
                $self->inventory_id($entry->{id});
                $logger->info("Inventory Switch_INV_".$self->switch_id." id retrieved successfully: ".$self->inventory_id());
                return $TRUE;
            }
        }
    } else {
        $logger->info("Inventory Switch_INV_".$self->switch_id." is not retrieved successfully");
        return $TRUE;
    }
}

sub createTemplate {
    my ($self) = @_;
    my $logger = get_logger();
    my $switch_id_path = $self->switch_id;
    $switch_id_path =~ s/\./_/g;
    my $content = encode_json({name => "Switch_ACLS_".$self->switch_id, playbook => "switch_acls.yml", inventory_id => $self->inventory_id, repository_id => 1, environment_id => 1, project_id => $self->project_id, type => ""});
    my $res = $self->_do_post("templates", $content);
    if($res->is_success) {
        $logger->info("Template Switch_ACLS_".$self->switch_id." created successfully");
        return $TRUE;
    } else {
        $logger->error("Template Switch_ACLS_".$self->switch_id." not created successfully");
        return $FALSE;
    }
}

sub getTemplate {
    my ($self) = @_;
    my $logger = get_logger();
    my $res = $self->_do_get("templates");
    if($res->is_success) {
        my $info = decode_json($res->decoded_content);
        foreach my $entry ( @{$info} ) {
            if ($entry->{name} eq "Switch_ACLS_".$self->switch_id) {
                $self->template_id($entry->{id});
                $logger->info("Template Switch_ACLS_".$self->switch_id." id retrieved successfully: ".$self->template_id());
                return $TRUE;
            }
        }
    } else {
        $logger->error("Template Switch_ACLS_".$self->switch_id." id not retrieved successfully");
        return $FALSE;
    }
}

sub launchTask {
    my ($self) = @_;
    my $logger = get_logger();
    my $switch_id_path = $self->switch_id;
    $switch_id_path =~ s/\./_/g;
    my $content = encode_json({template_id => $self->template_id});
    my $res = $self->_do_post("tasks", $content);
    if($res->is_success) {
        $logger->info("Task Switch_ACLS_".$self->switch_id." launched successfully");
        return $TRUE;
    } else {
        $logger->error("Task Switch_ACLS_".$self->switch_id." not launched successfully");
        return $FALSE;
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


=head2 logout

Logout from semaphore

=cut

sub logout {
    my ($self) = @_;
    my $logger = get_logger();
    my $res = $self->_do_post("logout");
    if($res->is_success) {
        $logger->info("Logout successfull");
        return $TRUE;
    } else {
        $logger->error("Logout not successfull");
        return $FALSE;
    }
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

=head2 _do_delete

Execute a DELETE request on the Semaphore API

=cut

sub _do_delete {
    my ($self, $uri) = @_;
    return $self->_execute_request(HTTP::Request::Common::DELETE($self->_build_uri($uri)));
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
        login         => "/api/auth/login",
        logout        => "/api/auth/logout",
        tokens        => "/api/user/tokens",
        projects      => "/api/projects",
        deleteproject => "/api/project/".$project_id."/",
        accesskeys    => "/api/project/".$project_id."/keys",
        repository    => "/api/project/".$project_id."/repositories",
        environment   => "/api/project/".$project_id."/environment",
        inventory     => "/api/project/".$project_id."/inventory",
        templates     => "/api/project/".$project_id."/templates",
        tasks         => "/api/project/".$project_id."/tasks",
    };
    my $path = $URIS->{$type};
    return $self->protocol."://".$self->host.":".$self->port."$path";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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


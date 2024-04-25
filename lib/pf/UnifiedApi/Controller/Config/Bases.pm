package pf::UnifiedApi::Controller::Config::Bases;

=head1 NAME

pf::UnifiedApi::Controller::Config::Bases - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Bases

=cut

use strict;
use warnings;
use pf::constants::pfconf;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::Pf';
has 'form_class' => 'pfappserver::Form::Config::Pf';
has 'primary_key' => 'base_id';

use pf::ConfigStore::Pf;
use pf::pfqueue::status_updater::redis;
use pf::util::pfqueue qw(consumer_redis_client);
use pf::config;
use pf::util;
use pf::file_paths qw($conf_uploads);
use pfappserver::Form::Config::Pf;
use pf::I18N::pfappserver;
use pf::error qw(is_error);
use pf::ConfigStore::Pf;
use pf::ConfigStore::Network;
use pfappserver::Model::Config::Pfconfig;
use pf::config qw(
    %Config
    %Doc_Config
);
use Data::UUID;

my $GENERATOR = Data::UUID->new;

sub _update_domain_networks_conf {
    my ($self) = @_;
    if($self->id eq "general" && isenabled($Config{advanced}{configurator}) && $self->get_json->{domain} ne $Config{general}{domain}) {
        $self->log->info("Domain name is being modified and configurator is active, will refresh the domain name value of all the networks already configured.");
        my $netcs = pf::ConfigStore::Network->new;
        for my $network (@{$netcs->readAll("id")}) {
            $network->{"domain-name"} = $network->{type} . "." . $self->get_json->{domain};
            $netcs->update($network->{id}, $network);
        }
        $netcs->commit();
    }
}

sub validate_item {
    my ($self, $item) = @_;
    my $id = $item->{id};
    while ( my ($key, $val) = each %$item) {
        my $doc_section = "$id.$key";
        unless (exists $Doc_Config{$doc_section} && defined $val  ) {
            next;
        }
        my $doc = $Doc_Config{$doc_section};
        my $doc_type = $doc->{type};
        if ($doc_type eq 'array' || $doc_type eq 'merged_list_array') {
            if (!ref $val) {
                $item->{$key} = [$val];
            }
        }
    }

    return $self->SUPER::validate_item($item);
}

sub field_placeholder {
    my ($self, $field, $defaults) = @_;
    my $section = $field->form->section;
    my $name = $field->name;
    my $doc_section = "$section.$name";
    my $doc_type = $Doc_Config{$doc_section}{type} // 'text';
    if ($doc_type eq 'merged_list' || $doc_type eq 'merged_list_array') {
        return undef;
    }

    return $self->SUPER::field_placeholder($field, $defaults);
}

sub replace {
    my ($self) = @_;
    $self->_update_domain_networks_conf();
    $self->SUPER::update();
}

sub update {
    my ($self) = @_;
    $self->_update_domain_networks_conf();
    $self->SUPER::update();
}

sub form_parameters {
    my ($self, $item) = @_;
    my $name = $self->id // $item->{id};
    if (!defined $name) {
        return [];
    }
    return [section => $name];
}

sub items {
    my ($self) = @_;
    my $cs = $self->config_store;
    my $items = $cs->readAll('id');
    return [
        map {$self->cleanup_item($_)} grep { exists $pf::constants::pfconf::ALLOWED_SECTIONS{$_->{id}} } @$items
    ];
}

sub cached_form {
    undef;
}

sub database_model {
    require pfappserver::Model::DB;
    return pfappserver::Model::DB->new;
}

sub database_test {
    my ($self) = @_;
    my $json = $self->get_json;
    unless($json) {
        $self->render(json => {message => "Unable to parse JSON payload"}, status => 400);
        return;
    }

    $json->{database} //= "mysql";
    my ($status, $status_msg) = $self->database_model->test_connection($json);
    $self->render(json => {message => pf::I18N::pfappserver->localize($status_msg)}, status => $status);
}

sub database_secure_installation {
    my ($self) = @_;
    my $json = $self->get_json;
    unless($json) {
        $self->render(json => {message => "Unable to parse JSON payload"}, status => 400);
        return;
    }

    if ($json->{async}) {
        my $task_id = $self->task_id;
        my $subprocess = Mojo::IOLoop->subprocess;
        $subprocess->run(
            sub {
                my ($subprocess) = @_;
                my $updater = pf::pfqueue::status_updater::redis->new( connection => consumer_redis_client(), task_id => $task_id );
                $updater->start;
                my ($status, $data) = $self->do_database_secure_installation($json);
                $updater->completed($data);
            },
            sub {},
        );

        return $self->render( json => {status => 202, task_id => $task_id }, status => 202);
    }

    my ($status, $data) = $self->do_database_secure_installation($json);
    return $self->render(json => $data, status => $status);
}

sub do_database_secure_installation {
    my ($self, $json) = @_;
    my ($status, $status_msg) = $self->database_model->connect("mysql", $json->{username});
    if(is_error($status)) {
        return $status, {message => pf::I18N::pfappserver->localize($status_msg), status => $status};
    }

    ($status, $status_msg) = $self->database_model->secureInstallation($json->{username}, $json->{password});
    return $status, {message => pf::I18N::pfappserver->localize($status_msg), status => $status};
}

sub database_create {
    my ($self) = @_;
    my $json = $self->get_json;
    unless($json) {
        $self->render(json => {message => "Unable to parse JSON payload"}, status => 400);
        return;
    }

    if ($json->{async}) {
        my $task_id = $self->task_id;
        my $subprocess = Mojo::IOLoop->subprocess;
        $subprocess->run(
            sub {
                my ($subprocess) = @_;
                my $updater = pf::pfqueue::status_updater::redis->new( connection => consumer_redis_client(), task_id => $task_id );
                $updater->start;
                my ($status, $data) = $self->do_database_create($json);
                $updater->completed($data);
            },
            sub {},
        );

        return $self->render( json => {status => 202, task_id => $task_id }, status => 202);
    }

    my ($status, $data) = $self->do_database_create($json);
    return $self->render(json => $data, status => $status);
}

sub do_database_create {
    my ($self, $json) = @_;
    my ($status, $status_msg) = $self->database_model->create_database($json);
    if(is_error($status)) {
        return $status, {message => pf::I18N::pfappserver->localize($status_msg), status => $status};
    }

    ($status, $status_msg) = $self->database_model->apply_schema($json);
    if(is_error($status)) {
        return $status, {message => pf::I18N::pfappserver->localize($status_msg), status => $status};
    }

    my $pf_cs = pf::ConfigStore::Pf->new;
    my $db = $json->{database};
    $pf_cs->update("database", {db => $db});
    $pf_cs->commit();
    pfappserver::Model::Config::Pfconfig->new->update_db_name($db);
    return 200, {message => "Created database and loaded the schema"};
}

sub database_assign {
    my ($self) = @_;
    my $json = $self->get_json;
    unless($json) {
        $self->render(json => {message => "Unable to parse JSON payload"}, status => 400);
        return;
    }

    my ($status, $status_msg) = $self->database_model->assign_database($json);
    if(is_error($status)) {
        $self->render(json => {message => pf::I18N::pfappserver->localize($status_msg)}, status => $status);
        return;
    }

    pfappserver::Model::Config::Pfconfig->new->update_mysql_credentials($json->{pf_username}, $json->{pf_password});

    my $pf_cs = pf::ConfigStore::Pf->new;
    my %database = (user => $json->{pf_username}, pass => $json->{pf_password});
    if ($json->{is_remote}) {
        my $remote = $json->{remote};
        my %database_proxysql = (
            status => 'enabled',
            backend => $remote->{host},
        );
        if ($remote->{ca_cert}) {
            my $path = "$conf_uploads/pf/database_proxysql_cacert.crt";
            open(my $fh, ">", $path);
            print $fh $remote->{ca_cert};
            close($fh);
            $database_proxysql{cacert} = $path;
        }
        $pf_cs->update("database_proxysql", \%database_proxysql);
        $database{port} = '6033';
        $database{host} = '100.64.0.1';
    }
    $pf_cs->update("database", \%database);
    $pf_cs->commit();
    $self->render(json => {message => "Granted rights to user and adjusted the configuration"}, status => 200);

    return;
}

sub test_smtp {
    my ($self) = @_;
    my ($error, $json) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my $form = $self->form({ id => "alerting" });
    $form->process(params => $json);
    if ($form->has_errors) {
        return $self->render_error(422, "Invalid parameters", $self->format_form_errors($form));
    }

    my $alerting_config = $form->value;
    my $email = $json->{'test_emailaddr'} || $alerting_config->{emailaddr};
    my $msg = MIME::Lite->new(
        To => $email,
        Subject => "PacketFence SMTP Test",
        Data => "PacketFence SMTP Test successful!\r\n"
    );

    my $results = eval {
        pf::config::util::do_send_mime_lite($msg, %$alerting_config);
    };

    if ($@) {
        return $self->render_error(400, pf::util::strip_filename_from_exceptions($@));
    }

    $self->render(json => { message => 'Testing SMTP success' });
    return;
}

=head2 fields_to_mask

fields_to_mask

=cut

sub fields_to_mask { qw(smtp_password pass galera_replication_password root_pass) }

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

package pf::UnifiedApi::Controller;

=head1 NAME

pf::UnifiedApi::Controller -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller

=cut

use strict;
use warnings;
use Mojo::Base 'Mojolicious::Controller';
use pf::error qw(is_error is_success);
use JSON::MaybeXS qw();
use pf::admin_roles;
use pf::dal::admin_api_audit_log;
use Mojo::JSON qw(encode_json);
has activity_timeout => 300;
has 'openapi_generator_class' => undef;
use Data::UUID;
use pfappserver::Form::Field::FingerbankSelect;
use pfappserver::Role::Form::RolesAttribute qw();

our $ERROR_400_MSG = "Bad Request. One of the submitted parameters has an invalid format";
our $ERROR_404_MSG = "Not Found. The requested resource could not be found";
our $ERROR_409_MSG = "An attempt to add a duplicate entry was stopped. Entry already exists and should be modified instead of created.";
our $ERROR_422_MSG = "Request cannot be processed because the resource has failed validation after the modification.";

our %STATUS_TO_MSG = (
    400 => $ERROR_400_MSG,
    404 => $ERROR_404_MSG,
    409 => $ERROR_409_MSG,
    422 => $ERROR_422_MSG,
);

my $GENERATOR = Data::UUID->new;

use Mojo::JSON qw(decode_json);
use pf::util;

sub after_dispatch {
    pfappserver::Form::Field::FingerbankSelect->clear_cache();
    pfappserver::Role::Form::RolesAttribute->_clear_roles();
}

sub log {
    my ($self) = @_;
    return $self->app->log;
}

sub reinitGenerator {
    $GENERATOR = Data::UUID->new;
}

sub render_error {
    my ($self, $code, $msg, $errors) = @_;
    $errors //= [];
    my $data = {message => $msg, errors => $errors, status => $code};
    $self->render(json => $data, status => $code);
    return 0;
}

sub render_empty {
    my ($self) = @_;
    return $self->render(text => '', status => 204);
}

sub status_to_error_msg {
    my ($self, $status) = @_;
    return exists $STATUS_TO_MSG{$status} ? $STATUS_TO_MSG{$status} : "Server error";
}

sub parse_json {
    my ($self, $body) = @_;
    $body //= $self->req->body;
    my $json = eval {
        JSON::MaybeXS::decode_json($body);
    };
    if ($@) {
        $self->log->error($@);
        return (400, { message => $self->status_to_error_msg(400)});
    }
    return (200, $json);
}

sub get_json {
    my ($self) = @_;
    local $@;
    my $error;
    my $data = eval {
        decode_json($self->tx->req->body);
    };
    if ($@) {
        $error = $@->message;
        $self->log->error($error);
        $error = strip_filename_from_exceptions($error);
    }
    return ($error, $data);
}

sub unknown_action {
    my ($self) = @_;
    return $self->render_error(404, "Unknown path " . $self->req->url->path);
}

sub openapi_generator {
    my ($self) = @_;
    my $class = $self->openapi_generator_class;
    return $class ? $class->new : undef;
}

sub json_true {
    return do { bless \(my $dummy = 1), "JSON::PP::Boolean" };
}

sub json_false {
    return do { bless \(my $dummy = 0), "JSON::PP::Boolean" };
}

sub _get_allowed_options {
    my ($self, $option) = @_;
    return admin_allowed_options($self->stash->{user_roles}, $option);
}

sub audit_request {
    my ($self) = @_;
    if ($self->is_auditable) {
        my $record = $self->make_audit_record();
        my $log = pf::dal::admin_api_audit_log->new($record);
        $log->insert;
    }
}

sub is_auditable {
    my ($self) = @_;
    return is_success($self->res->code) && $self->stash->{auditable};
}

=head2 make_audit_record

make_audit_record

=cut

sub make_audit_record {
    my ($self) = @_;
    my $stash = $self->stash;
    my $status =  $self->res->code;
    my $req = $self->req;
    my $method = $req->method;
    my $path = $req->url->path;
    my $request = $self->make_audit_record_request();
    my $object_id = $self->can("id") ? $self->id : undef;

    my $current_user = $stash->{current_user};
    return {
        user_name => $current_user,
        method => $method,
        request => $request,
        status => $status,
        action => $self->match->endpoint->name,
        url => $path,
        object_id => $object_id,
    }
}

=head2 make_audit_record_request

make_audit_record_request

=cut

sub make_audit_record_request {
    my ($self) = @_;
    my $json = $self->req->json;
    $self->cleanup_audit_record_request($json);
    return encode_json($json);
}

=head2 cleanup_audit_record_request

cleanup_audit_record_request

=cut

sub cleanup_audit_record_request {
    my ($self, $request) = @_;
    if (exists $request->{items}) {
        for my $item (@{$request->{items}}) {
            $self->cleanup_audit_item($item);
        }
    }

    $self->cleanup_audit_item($request);
}

sub cleanup_audit_item {
    my ($self, $request) = @_;
    if (ref($request) ne 'HASH') {
        return;
    }

    for my $f ($self->fields_to_mask) {
        if (exists $request->{$f}) {
            $request->{$f} = '************************';
        }
    }
}

sub fields_to_mask { qw(password) }

sub escape_url_param {
    my ($self, $param) = @_;
    return $param unless defined $param;
    $param =~ s/%2[fF]|~/\//g;
    return $param;
}

sub task_id {
    "ApiTask:" . $GENERATOR->create_str
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


package pf::WebAPI::REST;

=head1 NAME

pf::WebAPI::JSONRPC - jsonrpc apache handler

=cut

=head1 DESCRIPTION

pf::WebAPI::JSONRPC

=cut

use strict;
use warnings;
use JSON::MaybeXS;
use pf::log;
use pf::util::webapi;
use Apache2::RequestIO;
use Apache2::RequestRec;
use Apache2::Response;
use Sub::Util qw(subname);
use Apache2::Const -compile =>
  qw(DONE OK DECLINED HTTP_UNAUTHORIZED HTTP_NOT_IMPLEMENTED HTTP_UNSUPPORTED_MEDIA_TYPE HTTP_PRECONDITION_FAILED HTTP_NO_CONTENT HTTP_NOT_FOUND SERVER_ERROR HTTP_OK HTTP_INTERNAL_SERVER_ERROR);
use List::MoreUtils qw(any);
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(dispatch_to));

our %ALLOW_CONTENT_TYPE = (
    'application/json'        => undef,
);

our $CONTENT_TYPE = 'application/json';

sub allowed {return exists $ALLOW_CONTENT_TYPE{$_[0]}}

sub handler {
    my $logger = get_logger();
    use bytes;
    my ($self, $r) = @_;
    my $content = $self->get_all_content($r);
    my $data = eval {decode_json $content };
    if ($@) {
        my $error = $@;
        get_logger->error($error);
        return $self->send_response(
            $r,
            Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE,
            $self->make_error_object("Cannot parse request", $error),
        );
    }
    my $ref_type = ref $data;
    unless ($ref_type && $ref_type eq 'HASH') {
        get_logger->error("Invalid request");
        return $self->send_response(
            $r,
            Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE,
            $self->make_error_object("Invalid request"),
        );
    }

    my ($method, $id) = ($r->uri, 1);
    my $dispatch_to = $self->dispatch_to;
    my $method_sub;

    if(my $rest_method = $self->dispatch_to->restPath($method)){
        pf::log::get_logger->trace(sub { "Found method " . subname($rest_method) . " for REST path $method" });
        $method_sub = $rest_method;
    }
    # We fallback to using the method name
    else {
        substr($method, 0,1) = "";
        # We replace slashes with underscore
        $method =~ s/\//\_/g;

        unless ( $dispatch_to->isPublic($method) ) {
            get_logger->error("Invalid request no method defined or method is not public");
            return $self->send_response(
                $r,
                Apache2::Const::HTTP_NOT_FOUND,
                $self->make_error_object("Method '$method' not found"),
            );
        }
        else {
            $method_sub = sub { my $call_on = shift @_; $call_on->$method(@_) }
        }
    }

    my @args;
    my $response_content = '';
    if (exists $data->{'params'}) {
        my $params = $data->{'params'};
        if (ref($params) eq 'ARRAY') {
            @args = @$params;
        } else {
            @args = ($params);
        }
        pf::util::webapi::add_mac_to_log_context(\@args);
    }
    else {
        @args = ($data);
    }

    my $object;
    eval {
        $object = $method_sub->($self->dispatch_to, @args,$r->headers_in());
        unless(ref($object) eq "ARRAY" || ref($object) eq "HASH"){
            $object = {result => $object};
        }
    };
    if ($@) {
        my $error = $@;
        if(ref($error) eq "pf::api::error"){
            return $self->send_response($r, $error->status, $error->response);
        }
        else {
            get_logger->error($error);
            return $self->send_response(
                $r,
                Apache2::Const::HTTP_INTERNAL_SERVER_ERROR,
                $self->make_error_object($error)
            );
        }
    }

    return $self->send_response($r, Apache2::Const::HTTP_OK, $object);

    # Notify message defer until later
    $r->push_handlers(
        PerlCleanupHandler => sub {
            eval {$dispatch_to->$method(@args);};
            $logger->error($@) if $@;
        }
    );
    $r->content_type($CONTENT_TYPE);
    return Apache2::Const::HTTP_NO_CONTENT;
}

sub send_response {
    my ($self, $r, $status, $object) = @_;
    $r->custom_response($status, '');
    $r->content_type($CONTENT_TYPE);
    $r->status($status);
    if ($object) {
        my $response_content = encode_json($object);
        $r->print($response_content);
    }
    $r->rflush;
    return Apache2::Const::OK;
}

sub get_all_content {
    my ($self, $r) = @_;
    my $content = '';
    my $offset  = 0;
    my $cnt     = 0;
    do {
        $cnt = $r->read($content, 8192, $offset);
        $offset += $cnt;
    } while ($cnt == 8192);
    return $content;
}

sub make_error_object {
    my ($self, $message, $data) = @_;
    return {error => {message => $message, detail => $data}};
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

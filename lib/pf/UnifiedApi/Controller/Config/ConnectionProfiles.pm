package pf::UnifiedApi::Controller::Config::ConnectionProfiles;

=head1 NAME

pf::UnifiedApi::Controller::Config::ConnectionProfiles -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::ConnectionProfiles

=cut

use strict;
use warnings;
use Mojo::Base qw(pf::UnifiedApi::Controller::RestRoute);
use pf::ConfigStore::Profile;

has 'config_store_class' => 'pf::ConfigStore::Profile';

sub list {
    my ($self) = @_;
    my $cs = $self->config_store;
    $self->render(json => {items => $cs->readAll}, status => 200);
}

sub config_store {
    my ($self) = @_;
    $self->config_store_class->new;
}

sub resource {
    my ($self) = @_;
    my $id = $self->resource_id;
    my $cs = $self->config_store;
    if (!$cs->hasId($id)) {
        return $self->render_error(404, "Item ($id) not found");
    }
    return 1;
}

sub resource_id {
    my ($self) = @_;
    return $self->stash->{connection_profile_id};
}

sub get {
    my ($self) = @_;
    return $self->render(json => {item => $self->item});
}

sub item {
    my ($self) = @_;
    my $id = $self->resource_id;
    my $cs = $self->config_store;
    my $item = $cs->read($id, 'id');
    return $self->cleanup_item($item);
}

=begin

=cut

our %DEFAULT_VALUES = (
    "access_registration_when_registered" => "",
    "always_use_redirecturl" => "",
    "autoregister" => "",
    "billing_tiers" => "",
    "block_interval" => 0,
    "description" => "",
    "device_registration" => "",
    "dot1x_recompute_role_from_portal" => "",
    "filter" => "",
    "id" => "",
    "login_attempt_limit" => 0,
    "logo" => "",
    "preregistration" => "",
    "provisioners" => "",
    "redirecturl" => "",
    "reuse_dot1x_credentials" => "",
    "root_module" => "",
    "scans" => "",
    "sms_pin_retry_limit" => 0,
    "sms_request_limit" => 0,
    "sources" => ""
);

sub cleanup_item {
    my ($self, $item) = @_;
    my %cleaned;
    while (my ($k, $v) = each %DEFAULT_VALUES) {
        next if !exists $item->{$k};
        $cleaned{$k} = !exists $item->{$k} ? $v : defined $item->{$k} ? $item->{$k} : $v;
    }
    return \%cleaned;
}

sub create {
    my ($self) = @_;
    my $item = $self->cleanup_item($self->req->json);
    my $cs = $self->config_store;
    my $id = delete $item->{id};
    if ($cs->hasId($id)) {
        return $self->render_error(409, "An attempt to add a duplicate entry was stopped. Entry already exists and should be modified instead of created");
    }
    $cs->create($id, $item);
    $cs->commit;
    $self->res->headers->location($self->make_location_url($id));
    $self->render(status => 201, text => '');
}

sub make_location_url {
    my ($self, $id) = @_;
    my $url = $self->url_for;
    return "$url/$id";
}

sub remove {
    my ($self) = @_;
    my $id = $self->resource_id;
    my $cs = $self->config_store;
    $cs->remove($id, 'id');
    $cs->commit;
    $self->render_empty();
}

sub update {
    my ($self) = @_;
    my $id = $self->resource_id;
    my $item = $self->cleanup_item($self->req->json);
    my $cs = $self->config_store;
    $cs->update($self->resource_id, $self->cleanup_item($self->req->json));
    $cs->commit;
    $self->render(status => 200, json => { message => "$id updated"});
}

sub replace {
    my ($self) = @_;
    return $self->update;
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


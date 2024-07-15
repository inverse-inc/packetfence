package pf::UnifiedApi::Controller::Config::Switches;

=head1 NAME

pf::UnifiedApi::Controller::Config::Switches -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Switches

=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);
use Role::Tiny::With;
with 'pf::UnifiedApi::Controller::Config::SwitchRole';

has 'config_store_class' => 'pf::ConfigStore::Switch';
has 'form_class' => 'pfappserver::Form::Config::Switch';
has 'primary_key' => 'switch_id';

use pf::ConfigStore::Switch;
use pf::ConfigStore::SwitchGroup;
use pfappserver::Form::Config::Switch;
use pf::db;
use List::Util qw(first);
use pf::constants qw($TRUE $FALSE);

BEGIN {
    local $pf::db::NO_DIE_ON_DBH_ERROR = 1;
    pfappserver::Form::Config::Switch->new;
}

=head2 invalidate_cache

invalidate switch cache

=cut

sub invalidate_cache {
    my ($self) = @_;
    my $switch_id = $self->id;
    my $switch = pf::SwitchFactory->instantiate($switch_id);
    unless ( ref($switch) ) {
        return $self->render_error(422, "Cannot instantiate switch $switch");
    }

    $switch->invalidate_distributed_cache();
    return $self->render(status => 200, json => { });
}

=head2 precreate_acls

precreate switch ACLs

=cut

sub precreate_acls {
    my ($self) = @_;
    my $switch_id = $self->id;
    my $switch = pf::SwitchFactory->instantiate($switch_id);
    unless ( ref($switch) ) {
        return $self->render_error(422, "Cannot instantiate switch $switch");
    }

    $switch->generateACL();
    return $self->render(status => 200, json => { });
}

sub id {
    my ($self) = @_;
    my $id = $self->SUPER::id();
    $id =~ s/%2[fF]|~/\//g;
    return $id;
}

sub post_update {
    my ($self, $switch_id, $old) = @_;
    my $switch = pf::SwitchFactory->instantiate($switch_id);
    if ($switch) {
        $switch->generateAnsibleConfiguration($old,$FALSE);
    }
}

sub post_create {
    my ($self, $switch_id, $old) = @_;
    $self->post_update($switch_id, $old);
}

sub pre_remove {
    my ($self, $switch_id, $old) = @_;
    my $switch = pf::SwitchFactory->instantiate($switch_id);
    if ($switch) {
        $switch->generateAnsibleConfiguration($old,$TRUE);
    }
}

=head2 standardPlaceholder

standardPlaceholder

=cut

sub standardPlaceholder {
    my ($self) = @_;
    my $params = $self->req->query_params->to_hash;
    my $group = $params->{group} || $params->{type};
    if (!defined $group || $group eq 'default' ) {
        return $self->SUPER::standardPlaceholder();
    }

    my $cs = pf::ConfigStore::SwitchGroup->new;
    my $values = $cs->read($group, 'id');
    if (!defined $values) {
        return $self->SUPER::standardPlaceholder();
    }

    return $self->_cleanup_placeholder($self->cleanup_item($values));
}

sub cleanup_options {
    my ($self, $options, $placeholder) = @_;
    my $meta = $options->{meta};
    my $allowed_roles = $meta->{AccessListMapping}{item}{properties}{role}{allowed};
    my $vlanMapping = $placeholder->{VlanMapping};
    my $accessListMapping = $placeholder->{AccessListMapping};
    my $urlMapping = $placeholder->{UrlMapping};
    my $vpnMapping = $placeholder->{VpnMapping};
    my $interfaceMapping = $placeholder->{InterfaceMapping};
    my $roleMapping = $placeholder->{ControllerRoleMapping};
    my $networkMapping = $placeholder->{NetworkMapping};
    my $networkMappingFrom = $placeholder->{NetworkMappingFrom};
    for my $a (@{$allowed_roles}) {
        my $r = $a->{value};
        $meta->{"${r}Vlan"} = mapping_meta($r, $vlanMapping, 'vlan', $self->json_false);
        $meta->{"${r}AccessList"} = mapping_meta($r, $accessListMapping, 'accesslist', $self->json_false);
        $meta->{"${r}Url"} = mapping_meta($r, $urlMapping, 'url', $self->json_false);
        $meta->{"${r}Vpn"} = mapping_meta($r, $vpnMapping, 'vpn', $self->json_false);
        $meta->{"${r}Interface"} = mapping_meta($r, $interfaceMapping, 'interface', $self->json_false);
        $meta->{"${r}Role"} = mapping_meta($r, $roleMapping, 'controller_role', $self->json_false);
        $meta->{"${r}Network"} = mapping_meta($r, $networkMapping, 'network', $self->json_false);
        $meta->{"${r}NetworkFrom"} = mapping_meta($r, $networkMappingFrom, 'networkfrom', $self->json_false);
    }
}

sub mapping_meta {
    my ($role, $mapping, $f, $required) = @_;
    return {
        default => undef,
        type => "string",
        placeholder => mapping_placeholder($role, $mapping, $f),
        required => $required,
    };
}

sub mapping_placeholder {
    my ($role, $mapping, $f) = @_;
    my $m = first { $_->{role} eq $role  } @$mapping;
    return defined $m ? $m->{$f} : undef;
}

sub validate_item {
    my ($self, $item) = @_;
    return 422, { message => "Duplicate interface detected" }, undef if $self->_duplicate_item($item);
    return $self->SUPER::validate_item($item);
}

sub _duplicate_item {
    my ($self, $item) = @_;
    my @interfaces;
    foreach my $entry (@{$item->{'InterfaceMapping'}}) {
        push(@interfaces, split(',',$entry->{'interface'})) if (defined $entry->{'interface'});
    }
    my %duplicated;
    foreach my $interface (@interfaces) {
       next unless $duplicated{$interface}++;
       return 1;
    }
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

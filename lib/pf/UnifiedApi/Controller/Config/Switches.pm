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
    my $required = $self->json_false;

    # Pre-build hash lookups for O(1) access per role instead of O(n) linear scans
    my %vlan_map        = map { $_->{role} => $_->{vlan} }            @{$placeholder->{VlanMapping} // []};
    my %acl_map         = map { $_->{role} => $_->{accesslist} }      @{$placeholder->{AccessListMapping} // []};
    my %url_map         = map { $_->{role} => $_->{url} }             @{$placeholder->{UrlMapping} // []};
    my %vpn_map         = map { $_->{role} => $_->{vpn} }             @{$placeholder->{VpnMapping} // []};
    my %interface_map   = map { $_->{role} => $_->{interface} }       @{$placeholder->{InterfaceMapping} // []};
    my %role_map        = map { $_->{role} => $_->{controller_role} } @{$placeholder->{ControllerRoleMapping} // []};
    my %network_map     = map { $_->{role} => $_->{network} }         @{$placeholder->{NetworkMapping} // []};
    my %networkfrom_map = map { $_->{role} => $_->{networkfrom} }     @{$placeholder->{NetworkMappingFrom} // []};

    for my $a (@{$allowed_roles}) {
        my $r = $a->{value};
        $meta->{"${r}Vlan"}        = { default => undef, type => "string", placeholder => $vlan_map{$r},        required => $required };
        $meta->{"${r}AccessList"}  = { default => undef, type => "string", placeholder => $acl_map{$r},         required => $required };
        $meta->{"${r}Url"}         = { default => undef, type => "string", placeholder => $url_map{$r},         required => $required };
        $meta->{"${r}Vpn"}         = { default => undef, type => "string", placeholder => $vpn_map{$r},         required => $required };
        $meta->{"${r}Interface"}   = { default => undef, type => "string", placeholder => $interface_map{$r},   required => $required };
        $meta->{"${r}Role"}        = { default => undef, type => "string", placeholder => $role_map{$r},        required => $required };
        $meta->{"${r}Network"}     = { default => undef, type => "string", placeholder => $network_map{$r},     required => $required };
        $meta->{"${r}NetworkFrom"} = { default => undef, type => "string", placeholder => $networkfrom_map{$r}, required => $required };
    }
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

Copyright (C) 2005-2026 Inverse inc.

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

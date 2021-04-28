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

has 'config_store_class' => 'pf::ConfigStore::Switch';
has 'form_class' => 'pfappserver::Form::Config::Switch';
has 'primary_key' => 'switch_id';

use pf::ConfigStore::Switch;
use pf::ConfigStore::SwitchGroup;
use pfappserver::Form::Config::Switch;

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

sub id {
    my ($self) = @_;
    my $id = $self->SUPER::id();
    $id =~ s/%2[fF]|~/\//g;
    return $id;
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

sub form_parameters {
    [
        inactive => [ qw(always_trigger) ],
    ];
}

sub cleanupItemForUpdate {
    my ($self, $old_item, $new_data, $data) = @_;
    my %new_item;
    while ( my ($k, $v) = each %$data ) {
        $new_item{$k} = defined $v ? $new_data->{$k} : undef ;
    }
    %$new_data = %new_item;
    return;
}


sub defaultSearchInfo {
    raw => 1
}

=head2 fields_to_mask

fields_to_mask

=cut

sub fields_to_mask { qw(radiusSecret cliPwd wsPwd) }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

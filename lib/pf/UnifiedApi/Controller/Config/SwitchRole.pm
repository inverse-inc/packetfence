package pf::UnifiedApi::Controller::Config::SwitchRole;

=head1 NAME

pf::UnifiedApi::Controller::Config::SwitchRole -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::SwitchRole

=cut

use strict;
use warnings;
use Mojo::Base -role;
use pf::ConfigStore::Switch;

sub form_parameters {
    [
        inactive => [ qw(always_trigger) ],
    ];
}

sub cleanupItemForUpdate {
    my ($self, $old_item, $new_data, $data) = @_;
    my %new_item;
    pf::ConfigStore::Switch::_flattenRoleMappings($data);
    pf::ConfigStore::Switch::_flattenRoleMappings($new_data);
    pf::ConfigStore::Switch::_deleteRoleMappings($data);
    pf::ConfigStore::Switch::_deleteRoleMappings($new_data);
    while ( my ($k, $v) = each %$data ) {
        $new_item{$k} = defined $v ? $new_data->{$k} : undef ;
    }

    %$new_data = %new_item;
    return;
}

sub cleanupItemForGet {
    my ($self, $item) = @_;
    pf::ConfigStore::Switch::_flattenRoleMappings($item);
    return $item;
}

sub cleanupItemForCreate {
    my ($self, $item) = @_;
    pf::ConfigStore::Switch::_expandMapping($item);
    return $item;
}

sub mergeUpdate {
    my ($self, $patch, $old_item) = @_;
    my $mappings = makeMappings($patch);
    my $new_item = {%$old_item, %$patch};
    mergeMappings($new_item, $mappings);
    my $id = $self->id;
    $new_item->{id} = $id;
    delete $new_item->{not_deletable};
    return $new_item;
}
sub makeMappings {
    my ($patch) = @_;
    my %mapping;

    while (my ($k, $v) = each %$patch) {
        next unless ($k =~ /(.*)(AccessList|Vlan|Url|Role|Vpn|Interface|Network|NetworkFrom)$/);
        my $type = $2;
        my $role = $1;
        if ($type eq 'Role') {
            $type = 'ControllerRole';
        }
        $mapping{"${type}Mapping"}{$role} = $v;
        #delete $patch->{$k};
    }
    return \%mapping;
}

sub mergeMappings {
    my ($item, $mappings) = @_;
    while (my ($n, $m) = each %$mappings) {
        my $key = $pf::ConfigStore::Switch::MappingKey{$n};
        if (!exists $item->{$n}) {
            my @array;
            while (my ($role, $val) = each %$m) {
                push @array, { role => $role, $key => $val};
            }
            $item->{$n} = \@array;
            @array = sort { $a->{role} cmp $b->{role}  } @array;
            next;
        }

        my @array;
        my $ref = delete $item->{$n};
        for my $i (@$ref) {
            my $role = $i->{role};
            if (exists $m->{$role}) {
                my $val = delete $m->{$role};
                $i->{$key} = $val;
            }

            push @array, $i;
        }

        while (my ($role, $val) = each %$m) {
            push @array, { role => $role, $key => $val};
        }

        @array = sort { $a->{role} cmp $b->{role}  } @array;

        $item->{$n} = \@array;
    }
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

package captiveportal::DynamicRouting::util;

=head1 NAME

captiveportal::DynamicRouting::util

=head1 DESCRIPTION

Util methods for DynamicRouting

=cut

use strict;
use warnings;
use base qw(Exporter);
our @EXPORT = qw(
    clean_id generate_id generate_dynamic_module_id id_parts id_is_cyclic
);

use Tie::IxHash;
use pf::constants;

sub clean_id {
    my ($uid) = @_;
    $uid =~ s/^(.+)\+//g;
    return $uid;
}

sub generate_id {
    my ($parent_id, $id) = @_;
    return $parent_id . '+' . $id;
}

sub id_parts {
    my ($id) = @_;
    return split('\+', $id);
}

sub id_is_cyclic {
    my ($id) = @_;
    my @parts = id_parts($id);
    my %seen;
    foreach my $part (@parts){
        if(exists($seen{$part})){
            return $TRUE;
        }
        else {
            $seen{$part} = $TRUE;
        }
    }
    return $FALSE;
}

sub generate_dynamic_module_id {
    my ($id) = @_;
    return '_DYNAMIC_SOURCE_'.$id.'_';
}

sub modules_by_type {
    my ($items) = @_;
    tie my %items_by_type, 'Tie::IxHash', (
        Root => [], 
        Choice => [],
        Chained => [],
        Authentication => [],
        Provisioning => [],
    );
    my %type_map = (
        '^Authentication' => 'Authentication',
    );
    foreach my $item (@$items){
        my $regex_found = $FALSE;
        foreach my $regex (keys(%type_map)){
            if($item->{type} =~ /$regex/){
                $items_by_type{$type_map{$regex}} //= [];
                push @{$items_by_type{$type_map{$regex}}}, $item;
                $regex_found = $TRUE;
            }
        }
        unless($regex_found){
            $items_by_type{$item->{type}} //= [];
            push @{$items_by_type{$item->{type}}}, $item;
        }
    }
    return \%items_by_type;
};

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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


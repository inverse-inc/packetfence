package pf::factory::config;

=head1 NAME

pf::factory::config 

=cut

=head1 DESCRIPTION

pf::factory::config

The factory for creating pfconfig::cached based objects

=cut

use strict;
use warnings;
use pfconfig::cached_hash;
use pfconfig::cached_array;
use pfconfig::cached_scalar;

sub new {
    my ($class,$type,$namespace) = @_;

    if ($type eq "cached_hash") {
        my %object;
        tie %object, 'pfconfig::cached_hash', $namespace;
        return %object;
    }
    elsif ($type eq "cached_array"){
        my @object;
        tie @object, 'pfconfig::cached_array', $namespace;
        return @object;
    }
    elsif ($type eq "cached_scalar"){
        my $object;
        tie $object, 'pfconfig::cached_scalar', $namespace;
        return $object;
    }
    else {
        die "$type is not a valid type";
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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


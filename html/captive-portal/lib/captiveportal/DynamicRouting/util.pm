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
    clean_id generate_id generate_dynamic_module_id
);

our %MODULES_UID;

sub clean_id {
    my ($uid) = @_;
    $uid =~ s/^(.+)\+//g;
    return $uid;
}

sub generate_id {
    my ($parent_id, $id) = @_;
    return $parent_id . '+' . $id;
}

sub generate_dynamic_module_id {
    my ($id) = @_;
    return '_DYNAMIC_SOURCE_'.$id.'_';
}

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


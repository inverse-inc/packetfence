package pfconfig::namespaces::resource::roles_children;

=head1 NAME

pfconfig::namespaces::resource::roles_children

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::roles_children

=cut

use strict;
use warnings;

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;
    $self->{config} = $self->{cache}->get_cache('config::Roles');
}

sub build {
    my ($self) = @_;
    my %list;
    while(my ($role, $config) = each %{$self->{config}}) {
        my $parent = $config->{parent_id};
        while($parent) {
            $list{$parent} //= [];
            push @{$list{$parent}}, $role;
            $parent = $self->{config}->{$parent}->{parent_id};
        }
    }
    return \%list;
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:


package pfconfig::namespaces::config::Roles;

=head1 NAME

pfconfig::namespaces::config::Roles

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Roles

This module creates the configuration hash associated to roles.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw(
    $roles_default_config_file
    $roles_config_file
);
use pf::util qw(isenabled);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file}              = $roles_config_file;

    my $defaults = pf::IniFiles->new( -file => $roles_default_config_file );
    $self->{added_params}->{'-import'} = $defaults;
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{ $self->{cfg} };
    my %parents;
    while ( my ($name, $data) = each %tmp_cfg ) {
        if (exists $data->{acls} && defined $data->{acls}) {
            $data->{acls} = [split(/\n/, $data->{acls})];
        }

        my $parent = $data->{parent} // '';
        push @{$parents{$parent}}, [$name, $data];
    }
    _flatten_nodecategory($parents{''}, \%parents);

    return \%tmp_cfg;
}

sub _flatten_nodecategory {
    my ( $parents, $h ) = @_;
    for my $parent (@$parents) {
        my $pname = $parent->[0];
        next if !exists $h->{$pname};
        my $data = $parent->[1];
        my %inherited;
        for my $child (@{$h->{$pname} // []}) {
            push @{$data->{children}}, $child->[0];
            my $cdata = $child->[1];
            while (my ($k, $v) = each %$data) {
                next if $k eq 'parent' || $k eq 'children';
                if (!exists $cdata->{$k} || !defined $cdata->{$k}) {
                    $cdata->{$k} = $v;
                    $inherited{$k} = undef;
                }
            }

            if ($cdata->{parent} && isenabled($cdata->{include_parent_acls}) && !exists $inherited{acls}) {
                push @{$cdata->{acls}}, @{$data->{acls} // []};
            }
        }
    }

    return @$parents,
      map { _flatten_nodecategory( $h->{$_}, $h ) }
      grep { exists $h->{$_} } map { $_->[0] } @$parents;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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


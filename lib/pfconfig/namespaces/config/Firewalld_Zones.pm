package pfconfig::namespaces::config::Firewalld_Zones;

=head1 NAME

pfconfig::namespaces::config::Firewalld_Zones

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Firewalld_Zones

This module creates the configuration hash associated to firewalld_zones*.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::IniFiles;
use pf::file_paths qw(
    $firewalld_zones_config_defaults_file
    $firewalld_zones_config_file
);
use pf::util;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;

    $self->{file} = $firewalld_zones_config_file;
    $self->{child_resources} = [ "resource::all_firewalld" ];

    my $defaults = pf::IniFiles->new( -file => $firewalld_zones_config_defaults_file, -envsubst => 1);
    $self->{added_params}->{'-import'} = $defaults;
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{ $self->{cfg} };

    $self->cleanup_whitespaces( \%tmp_cfg );

    return \%tmp_cfg;
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

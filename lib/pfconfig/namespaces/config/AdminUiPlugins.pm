package pfconfig::namespaces::config::AdminUiPlugins;

=head1 NAME

pfconfig::namespaces::config::AdminUiPlugins

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::AdminUiPlugins

This module creates the configuration hash associated to admin_ui_plugins.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw($admin_ui_plugins_config_file);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $admin_ui_plugins_config_file;
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{ $self->{cfg} };
    $self->cleanup_whitespaces( \%tmp_cfg );

    for my $id (keys %tmp_cfg) {
        my $plugin = $tmp_cfg{$id};
        $plugin->{enabled} //= 'enabled';
        $plugin->{acl} ||= 'SYSTEM';
        $plugin->{config_files} = [
            map {
                my ($path, $namespace) = split(/:/, $_, 2);
                { path => $path, namespace => $namespace }
            } grep { length } split(/\s*,\s*/, $plugin->{config_files} // '')
        ];
    }

    return \%tmp_cfg;
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

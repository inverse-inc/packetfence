package pf::ConfigStore::AdminUiPlugins;

=head1 NAME

pf::ConfigStore::AdminUiPlugins

=cut

=head1 DESCRIPTION

Config store for the admin UI plugins (admin_ui_plugins.conf)

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($admin_ui_plugins_config_file);
extends 'pf::ConfigStore';

sub configFile { $admin_ui_plugins_config_file };

sub pfconfigNamespace { 'config::AdminUiPlugins' }

=head2 cleanupAfterRead

Clean up data

=cut

sub cleanupAfterRead {
    my ($self, $id, $data) = @_;
    $self->expand_list($data, $self->_fields_expanded);
    # the manifest is a multi-line JSON document
    my $manifest = $data->{manifest};
    if (ref($manifest) eq 'ARRAY') {
        $data->{manifest} = join("\n", @{$manifest});
    }
}

=head2 cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $data) = @_;
    $self->flatten_list($data, $self->_fields_expanded);
}

=head2 _fields_expanded

=cut

sub _fields_expanded {
    return qw(config_files);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

package pf::ConfigStore::Connector;
=head1 NAME

pf::ConfigStore::Connector add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::Connector

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($connectors_config_file);
use pf::connector::site_network qw(expand_site_network flatten_site_network);
extends 'pf::ConfigStore';

sub configFile { $connectors_config_file };

sub pfconfigNamespace { 'config::Connector' }

=head2 cleanupAfterRead

Expand the site networking line lists (interfaces, routes) into structured
lists. See pf::connector::site_network for the formats.

=cut

sub cleanupAfterRead {
    my ($self, $id, $item) = @_;
    expand_site_network($item);
}

=head2 cleanupBeforeCommit

Flatten the structured site networking lists back into one line per entry.

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $item) = @_;
    flatten_site_network($item);
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


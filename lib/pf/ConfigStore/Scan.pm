package pf::ConfigStore::Scan;
=head1 NAME

pf::ConfigStore::Scan add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::Scan

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($scan_config_file);
extends 'pf::ConfigStore';
with 'pf::ConfigStore::Role::ReverseLookup';
use pfconfig::cached_hash;
tie our %ProfileReverseLookup, 'pfconfig::cached_hash', 'resource::ProfileReverseLookup';

sub configFile { $scan_config_file };

sub pfconfigNamespace {'config::Scan'}

=head2 canDelete

canDelete

=cut

sub canDelete {
    my ($self, $id) = @_;
    return !$self->isInProfile('scans', $id) && $self->SUPER::canDelete($id);
}

=head2 cleanupAfterRead

Clean up switch data

=cut

sub cleanupAfterRead {
    my ($self, $id, $profile) = @_;
    $self->expand_list($profile, $self->_fields_expanded);
}

=head2 cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $profile) = @_;
    $self->flatten_list($profile, $self->_fields_expanded);
}

=head2 _fields_expanded

=cut

sub _fields_expanded {
    return qw(categories oses rules);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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


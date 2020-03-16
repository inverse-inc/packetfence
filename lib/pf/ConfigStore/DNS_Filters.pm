package pf::ConfigStore::DNS_Filters;

=head1 NAME

pf::ConfigStore::DNS_Filters add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::DNS_Filters

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($dns_filters_config_file);
extends 'pf::ConfigStore';
use pf::condition_parser qw(parse_condition_string ast_to_object);

sub configFile { $dns_filters_config_file };

sub pfconfigNamespace {'config::DNS_Filters'}

=head2 cleanupBeforeCommit

cleanupBeforeCommit

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $item) = @_;
    $self->flatten_to_ordered_array($item, 'actions', 'action');
    $item->{condition} = pf::condition_parser::object_to_str($item->{condition});
    $self->flatten_list($item, $self->_fields_expanded);
    return ;
}

sub cleanupAfterRead {
    my ($self, $id, $item, $idKey) = @_;
    $self->expand_ordered_array($item, 'actions', 'action');
    $self->expand_list($item, $self->_fields_expanded);
    my ($ast, $err) = parse_condition_string($item->{condition});
    $item->{condition} = ast_to_object($ast);
    return;
}

=head2 _fields_expanded

=cut

sub _fields_expanded {
    return qw(scopes);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

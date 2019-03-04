package pf::ConfigStore::PortalModule;
=head1 NAME

pf::ConfigStore::PortalModule
Store Portal modules configuration

=cut

=head1 DESCRIPTION

pf::ConfigStore::PortalModule

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw(
    $portal_modules_config_file
    $portal_modules_default_config_file
);
extends 'pf::ConfigStore';
with 'pf::ConfigStore::Role::ReverseLookup';

use pf::log;

sub configFile { $portal_modules_config_file};

sub importConfigFile { $portal_modules_default_config_file }

sub pfconfigNamespace {'config::PortalModules'}

=head2 canDelete

canDelete

=cut

sub canDelete {
    my ( $self, $id ) = @_;
    return
         !$self->isInProfile( 'root_module', $id )
      && !$self->isInPortalModules( 'modules', $id )
      && $self->SUPER::canDelete($id);
}

=head2 cleanupAfterRead

Clean up portal modules data

=cut

sub cleanupAfterRead {
    my ($self, $id, $object) = @_;
    $self->expand_list($object, $self->_fields_expanded);
    $self->expand_lines($object, $self->_fields_line_expanded);

    # This can be an array if it's fresh out of the file. We make it separated by newlines so it works fine the frontend
    if($object->{type} eq "Message" && ref($object->{message}) eq 'ARRAY'){
        $object->{message} = join("\n", @{$object->{message}});
    }

    # Multiple sources are stored in this special field to the admin forms can display it differently
    $object->{multi_source_ids} = $object->{source_id}; 
}

=head2 cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $object) = @_;
    
    # portal_modules.conf always stores sources in source_id whether they are multiple or single, so we take multi_source_ids and put it in source_id
    if (defined($object->{multi_source_ids}) && scalar(@{$object->{multi_source_ids}}) > 0) {
        get_logger->debug("Multiple sources were defined for this object, taking the content of multi_source_ids to put it in source_id");
        $object->{source_id} = delete $object->{multi_source_ids};
    } else {
        delete $object->{multi_source_ids};
    }

    $self->flatten_list($object, $self->_fields_expanded);
    $self->join_lines($object, $self->_fields_line_expanded);
}

=head2 _fields_expanded

=cut

sub _fields_expanded {
    return qw(
    modules
    source_id
    multi_source_ids
    custom_fields
    actions
    );
}

sub expand_lines{
    my ($self, $data, @fields) = @_;
    foreach my $field (@fields){
        if(defined($data->{$field})){
            $data->{$field} = join("\n", split(',', $data->{$field}));
        }
    }
}

sub join_lines {
    my ($self, $data, @fields) = @_;
    foreach my $field (@fields){
        if(defined($data->{$field})){
            $data->{$field} = join(',', split(/\n/, $data->{$field}));
        }
    }
}

sub _fields_line_expanded {
    return qw(
    multi_source_types multi_source_auth_classes multi_source_object_classes
    );
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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


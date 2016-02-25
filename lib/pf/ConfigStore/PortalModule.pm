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
use pf::file_paths;
extends 'pf::ConfigStore';

sub configFile { $portal_modules_config_file};

sub pfconfigNamespace {'config::PortalModules'}

sub _buildCachedConfig {
    my ($self) = @_;
    return pf::config::cached->new(
        -file         => $portal_modules_config_file,
        -allowempty   => 1,
        -import       => pf::config::cached->new(-file => $portal_modules_default_config_file),
        -onpostreload => [
            'reload_portal_modules_config' => sub {
                my ($config) = @_;
                $config->{imported}->ReadConfig;
              }
        ],
    );
}

=head2 cleanupAfterRead

Clean up portal modules data

=cut

sub cleanupAfterRead {
    my ($self, $id, $profile) = @_;
    $self->expand_list($profile, $self->_fields_expanded);
    $self->expand_lines($profile, $self->_fields_line_expanded);
}

=head2 cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $profile) = @_;
    $self->flatten_list($profile, $self->_fields_expanded);
    $self->join_lines($profile, $self->_fields_line_expanded);
}

=head2 _fields_expanded

=cut

sub _fields_expanded {
    return qw(
    modules 
    source_id 
    custom_fields
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

__PACKAGE__->meta->make_immutable;

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


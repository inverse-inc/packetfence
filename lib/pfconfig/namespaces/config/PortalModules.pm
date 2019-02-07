package pfconfig::namespaces::config::PortalModules;

=head1 NAME

pfconfig::namespaces::config::PortalModules

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::PortalModules

This module creates the configuration hash associated to portal_modules.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw(
    $portal_modules_default_config_file
    $portal_modules_config_file
);
use pf::IniFiles;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $portal_modules_config_file;

    my $defaults = pf::IniFiles->new( -file => $portal_modules_default_config_file );
    $self->{added_params}->{'-import'} = $defaults;
    $self->{child_resources} = ['resource::PortalModuleReverseLookup'];
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{$self->{cfg}};
    my %reverseLookup;
    while ( my ($key, $module) = each %tmp_cfg) {
        $self->expand_list($module, qw(modules fields_to_save custom_fields multi_source_types multi_source_auth_classes multi_source_object_classes));
        foreach my $field (qw(modules source_id)) {
            my $values = $module->{$field};
            if (ref ($values) eq '') {
                next if !defined $values || $values eq '';

                $values = [$values];
            }

            for my $val (@$values) {
                push @{$reverseLookup{$field}{$val}}, $key;
            }
        }
        my $actions = $module->{actions};
        if (defined $actions) {
            if ($actions) {
                $self->expand_list($module, qw(actions));
                $module->{actions} = inflate_actions($module->{actions});
            }
            else {
                delete $module->{actions};
            }
        }
    }

    $self->{reverseLookup} = \%reverseLookup;

    return \%tmp_cfg;
}

=head2 inflate_actions

Inflate an array ref of actions to a hash ref of the format :
  {
    "action_name_1" => [
      "arg1",
      "arg2",
      "arg3"
    ]
    ...
  }

=cut

sub inflate_actions {
    my ($actions) = @_;
    my $new_actions = {};
    foreach my $action (@$actions){
        my ($action_name, $action_args) = inflate_action($action);
        $new_actions->{$action_name} = $action_args;
    }
    return $new_actions;
}

=head2 inflate_action

Inflate an action of the format action_name_1(arg1,arg2,arg3) to the following :
 (
  "action_name_1",
  [
    "arg1",
    "arg2",
    "arg3"
  ]
 )

=cut

sub inflate_action {
    my ($action) = @_;
    if($action =~ /(.+)\((.*)\)/){
        my $action_name = $1;
        my $action_params = $2;
        return ($action_name, [split(/\s*;\s*/, $action_params)]);
    }
}

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:



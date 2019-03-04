package pf::ConfigStore::Roles;
=head1 NAME

pf::ConfigStore::Roles

=cut

=head1 DESCRIPTION

Store and manipulate roles configuration

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($roles_config_file $roles_default_config_file);
use pf::nodecategory;
use pf::config;
extends 'pf::ConfigStore';

sub configFile { $roles_config_file };
sub importConfigFile { $roles_default_config_file }

sub pfconfigNamespace {'config::Roles'}

=item commit

Repopulate the node_category table after commiting

=cut

sub commit {
    my ($self) = @_;
    my ($result, $error) = $self->SUPER::commit();
    pf::log::get_logger->info("commiting via Roles configstore");
    nodecategory_populate_from_config( \%pf::config::ConfigRoles );
    return ($result, $error);
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



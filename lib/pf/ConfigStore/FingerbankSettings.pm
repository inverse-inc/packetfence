package pf::ConfigStore::FingerbankSettings;

=head1 NAME

pf::ConfigStore::FingerbankSettings

=cut

=head1 DESCRIPTION

pf::ConfigStore::FingerbankSettings

=cut

use Moo;
use namespace::autoclean;
use pf::config qw();
use pf::IniFiles;
use pf::file_paths qw($fingerbank_config_file $fingerbank_default_config_file);

extends 'pf::ConfigStore';

=head2 Methods

=cut

sub configFile { $fingerbank_config_file };

sub importConfigFile { $fingerbank_default_config_file }

sub pfconfigNamespace {'config::FingerbankSettings'}

=head2 remove

Delete an existing item

=cut

sub remove { return; }

=head2 cleanupAfterRead

=cut

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

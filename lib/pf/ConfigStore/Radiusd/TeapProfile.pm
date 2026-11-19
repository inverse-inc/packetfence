package pf::ConfigStore::Radiusd::TeapProfile;

=head1 NAME

pf::ConfigStore::Radiusd::TeapProfile

=cut

=head1 DESCRIPTION

Config store for the EAP-TEAP profiles in conf/radiusd/teap.conf, with the
shipped defaults imported from conf/radiusd/teap.conf.defaults. Changes are
exposed through the pfconfig namespace config::Teap.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moo;
use namespace::autoclean;
use pf::constants;
use pf::file_paths qw(
    $teap_config_file
    $teap_default_config_file
);
use pf::ConfigStore::Radiusd::EAPProfile;
extends 'pf::ConfigStore';


sub configFile { $teap_config_file }

sub pfconfigNamespace {'config::Teap'}

sub default_section { 'default' }

sub importConfigFile { $teap_default_config_file }

=head2 canDelete

A TEAP profile referenced by an EAP profile cannot be deleted: eap.conf would
render an empty teap block and radiusd would not start.

=cut

sub canDelete {
    my ($self, $id) = @_;
    my @users = map { $_->{id} }
      grep { ($_->{teap_config} // '') eq $id }
      @{ pf::ConfigStore::Radiusd::EAPProfile->new->readAll('id') };
    if (@users) {
        return "Used by the EAP profile(s): " . join(', ', @users), $FALSE;
    }

    return $self->SUPER::canDelete($id);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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


package pfappserver::Model::Configurator;

=head1 NAME

pfappserver::Model::Configurator - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Apache::Htpasswd;
use Moose;
use Readonly;
use namespace::autoclean;

use pf::log;
use pf::config qw(%Config);
use pf::file_paths qw($install_dir $conf_dir);
use pf::error;
use pf::util;
use Perl::Version;
use pf::ConfigStore::Pf;

extends 'Catalyst::Model';

=head1 METHODS

=over

=item checkForRootUser

=cut

sub checkForRootUser {
    my ( $self ) = @_;
    my $logger = get_logger();

    my $status_msg;

    unless ( $< == 0 ) {
        $status_msg = "The pfappserver must run under the root user";
        $logger->error($status_msg);
        return ( 0, $status_msg );
    }

    return 1;
}

=item isEnabled

=cut

sub isEnabled {
    my ( $self ) = @_;
    return isenabled($Config{advanced}{configurator});
}

=item disableConfigurator

=cut

sub disableConfigurator {
    my $cs = pf::ConfigStore::Pf->new;
    $cs->update(advanced => {configurator => "disabled"});
    return $cs->commit();
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

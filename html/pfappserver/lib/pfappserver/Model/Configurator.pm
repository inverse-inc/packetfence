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
use pf::config;
use pf::file_paths qw($install_dir $conf_dir);
use pf::error;
use pf::util;
use Perl::Version;

extends 'Catalyst::Model';

Readonly::Scalar our $CONFIGURATION => 'configuration';
Readonly::Scalar our $INSTALLATION => 'installation';
Readonly::Scalar our $UPGRADE => 'upgrade';

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

=item checkForUpgrade

=cut

sub checkForUpgrade {
    my ( $self ) = @_;
    my $logger = get_logger();

    my $filehandler;

    if ( !(-e "$install_dir/conf/currently-at") ) {
        return $INSTALLATION;
    }

    open( $filehandler, '<', "$install_dir/conf/currently-at" );
    chomp (my $currently_at = <$filehandler>);
    close( $filehandler );

    open( $filehandler, '<', "$install_dir/conf/pf-release" );
    chomp(my $pf_release = <$filehandler>);
    close( $filehandler );
    $logger->info("Currently at $currently_at, running release $pf_release");

    if ( (!$currently_at) || ($currently_at eq $pf_release) ) {
        $logger->info("Configuration process");
        return $CONFIGURATION;
    } else {
        $currently_at =~ s/PacketFence //;
        $currently_at =~ s/-/_/;
        $pf_release =~ s/PacketFence //;
        $pf_release =~ s/-/_/;
        if ($currently_at =~ Perl::Version::MATCH) {
            my $current_version = Perl::Version->new($currently_at);
            my $release_version = Perl::Version->new($pf_release);
            if($current_version->revision < $release_version->revision || $current_version->version < $release_version->version) {
                $logger->info("Upgrade process");
                return $UPGRADE;
            } else {
                $logger->info("Minor Change");
                return $CONFIGURATION;
            }
        } else {
            return $INSTALLATION;
        }
    }
}

=item upate_currently_at

=cut

sub update_currently_at {
    my ( $self ) = @_;
    my $logger = get_logger();

    open PFRELEASE, '<', "$conf_dir/pf-release";
    my @pfrelease  = <PFRELEASE>;
    close PFRELEASE;

    open CURRENTLYAT, '>', "$conf_dir/currently-at";
    print CURRENTLYAT @pfrelease;
    close CURRENTLYAT;

    return $STATUS::OK;
}

=back

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

package pf::version;

=head1 NAME

pf::version

=cut

=head1 DESCRIPTION

Handles versioning checking routines

=cut

use strict;
use warnings;

use pf::constants;
use pf::file_paths qw($conf_dir);
use pf::log;
use pf::dal::pf_version;
use pf::error qw(is_error);

my $logger = get_logger();

=head1 SUBROUTINES

=head2 version_check_db

Checks the version of database schema

=cut

sub version_check_db {
    my $current_pf_minor_version = version_get_current();
    $current_pf_minor_version =~ s/(\.\d+).*$/$1/; # Keeping only the major/minor part (i.e: X.Y.Z -> X.Y)
    my ($status, $iterator) = pf::dal::pf_version->search(
        -where => {
            version => {'LIKE' => "${current_pf_minor_version}.%" },
        }
    );

    if (is_error($status)) {
        return undef;
    }

    my $row = $iterator->next;
    unless ( $row ) {
        $logger->error("Can't get any result from DB while trying to check for database schema version");
        return undef;
    }

    return $row->{version};
}

=head2 version_get_last_db_version_sql

Get the last schema version in the datbase

=cut

sub version_get_last_db_version {
    my ($status, $iterator) = pf::dal::pf_version->search(
        -limit => 1,
        -order_by => {-desc => 'id'},
    );

    if (is_error($status)) {
        return undef;
    }
    my $row = $iterator->next;
    unless ( $row ) {
        $logger->error("Can't get any result from DB while trying to check for database schema version");
        return undef;
    }

    return $row->{version};
}

=head2 version_get_release

Get the current release of PacketFence

i.e: PacketFence X.Y.Z

=cut

sub version_get_release {
    my ( $pfrelease_fh, $release );
    open( $pfrelease_fh, '<', "$conf_dir/pf-release" )
        || get_logger->logdie("Unable to open $conf_dir/pf-release: $!");

    $release = <$pfrelease_fh>;
    close($pfrelease_fh);
    chomp($release);
    return $release ;
}

=head2 version_get_current

Get the current version of PacketFence

i.e: X.Y.Z

=cut

sub version_get_current {
    my $release = version_get_release();
    return undef unless $release;

    my $version = $release;
    $version =~ s/^PacketFence //;
    return $version ;
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

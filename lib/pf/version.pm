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
use pf::db;
use pf::file_paths qw($conf_dir);
use pf::log;

use constant PF_VERSION => 'version';

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $version_db_prepared = 0;

# In this hash reference we hold the database statements. We pass it to the query handler and it will repopulate
# the hash if required.
our $version_statements = {};

=head1 SUBROUTINES

=head2 version_db_prepare

Initialize database prepared statements

=cut

sub version_db_prepare {

    $version_statements->{'version_check_db_sql'} = get_db_handle()->prepare(qq[
        SELECT version FROM pf_version WHERE version LIKE ?;
    ]);

    $version_statements->{'version_get_last_db_version_sql'} = get_db_handle()->prepare(qq[
        SELECT version FROM pf_version ORDER BY id DESC limit 1;
    ]);

    $version_db_prepared = 1;
    return 1;
}

=head2 version_check_db

Checks the version of database schema

=cut

sub version_check_db {
    my $logger = get_logger();

    my $current_pf_minor_version = version_get_current();
    $current_pf_minor_version =~ s/(\.\d+).*$/$1/; # Keeping only the major/minor part (i.e: X.Y.Z -> X.Y)

    my $sth = db_query_execute(PF_VERSION, $version_statements, 'version_check_db_sql', $current_pf_minor_version . '.%');
    unless ( $sth ) {
        $logger->error("Can't get DB handle while trying to check for database schema version");
        return undef;
    }

    my $row = $sth->fetch;
    $sth->finish;
    unless ( $row ) {
        $logger->error("Can't get any result from DB while trying to check for database schema version");
        return undef;
    }

    return $row->[0];
}

=head2 version_get_last_db_version_sql

Get the last schema version in the datbase

=cut

sub version_get_last_db_version {
    my $logger = get_logger();

    my $sth = db_query_execute(PF_VERSION, $version_statements, 'version_get_last_db_version_sql');
    unless ( $sth ) {
        $logger->error("Can't get DB handle while trying to check for database schema version");
        return undef;
    }

    my $row = $sth->fetch;
    $sth->finish;
    unless ( $row ) {
        $logger->error("Can't get any result from DB while trying to check for database schema version");
        return undef;
    }

    return $row->[0];
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

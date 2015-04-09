package pf::version;
=head1 NAME

pf::version add documentation

=cut

=head1 DESCRIPTION

pf::version

=cut

use strict;
use warnings;

use pf::constants;
use pf::file_paths;
use pf::db;
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

    $version_statements->{'version_check_sql'} = get_db_handle()->prepare(qq[
            SELECT version FROM pf_version WHERE version = ?;
    ]);
    $version_db_prepared = 1;
    return 1;
}

=head2 version_check

Checks the version of db

=cut

sub version_check {
   my $sth = db_query_execute(PF_VERSION, $version_statements, 'version_check_sql', version_current());
   return unless $sth;
   my $row = $sth->fetch;
   $sth->finish;
   return unless $row;
   return $row->[0];
}

=head2 version_release

Get the current release of packetence

=cut

sub version_release {
    my ( $pfrelease_fh, $release );
    open( $pfrelease_fh, '<', "$conf_dir/pf-release" )
        || get_logger->logdie("Unable to open $conf_dir/pf-release: $!");
    $release = <$pfrelease_fh>;
    close($pfrelease_fh);
    chomp($release);
    return $release ;
}

=head2 version_current

Get the current version of packetence

=cut

sub version_current {
    my $release = version_release();
    return undef unless $release;
    my $version = $release;
    $version =~ s/^PacketFence //;
    return $version ;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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


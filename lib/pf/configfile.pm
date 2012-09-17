package pf::configfile;

=head1 NAME

pf::configfile - module to store the configuration files in the 
database.

=cut

=head1 DESCRIPTION

pf::configfile contains the functions necessary to store/read a 
configuration file to the database. PacketFence stores the 
configuration files in the database after every configuration change
through the web interface or a C<pfcmd> call. In a redundancy setup, in 
case of a failover, you need to manually pull the configuration files 
out of the database in order to be up-to-date.

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;

use Log::Log4perl;
use File::Copy;

use constant CONFIGFILE => 'configfile';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        configfile_db_prepare
        $configfile_db_prepared

        configfile_import
        configfile_export
        configfile_add
        configfile_update
        configfile_view
        configfile_exist
    );
}

use pf::config;
use pf::util;
use pf::db;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $configfile_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $configfile_statements = {};

sub configfile_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::configfile');
    $logger->debug("Preparing pf::configfile database queries");

    $configfile_statements->{'configfile_update_sql'} = get_db_handle()->prepare(
        qq[ update configfile set filecontent=?, lastmodified=from_unixtime(?) where filename=? ]);

    $configfile_statements->{'configfile_add_sql'} = get_db_handle()->prepare(
        qq[ insert into configfile(filename,filecontent,lastmodified) values(?,?,from_unixtime(?)) ]);

    $configfile_statements->{'configfile_exist_sql'} = get_db_handle()->prepare(
        qq[ select filename from configfile where filename=? ]);

    $configfile_statements->{'configfile_exist_new_sql'} = get_db_handle()->prepare(
        qq[ select filename from configfile where filename=? and unix_timestamp(lastmodified) > ? ]);

    $configfile_statements->{'configfile_exist_old_sql'} = get_db_handle()->prepare(
        qq[ select filename from configfile where filename=? and unix_timestamp(lastmodified) < ? ]);

    $configfile_statements->{'configfile_view_sql'} = get_db_handle()->prepare(
        qq[ select filename,filecontent,lastmodified from configfile where filename=? ]);

    $configfile_db_prepared = 1;
}

sub configfile_import {
    my ($filename) = @_;
    my $logger = Log::Log4perl::get_logger('pf::configfile');
    if ( !configfile_exist($filename) ) {
        $logger->info(
            "config file $filename does not exist in database; addind new database entry"
        );
        configfile_add($filename);
    } else {
        if ( configfile_db_is_old($filename) ) {
            $logger->info(
                "config file $filename is outdated in database; updating database entry"
            );
            configfile_update($filename);
        }
    }
}

sub configfile_export {
    my ($filename) = @_;
    my $logger = Log::Log4perl::get_logger('pf::configfile');
    if ( !configfile_exist($filename) ) {
        $logger->info(
            "config file $filename does not exist in database; unable to export"
        );
    } else {
        if ( configfile_db_is_new($filename) ) {
            $logger->info(
                "config file $filename is outdated on filesystem; updating dfile"
            );
            copy( $filename, "$filename-" . time() );
            my $data = configfile_view($filename);
            open my $export_fh, '>', $filename;
            print {$export_fh} $data->{'filecontent'};
            close $export_fh;
        }
    }
}

sub configfile_exist {
    my ($filename) = @_;

    my $query = db_query_execute(CONFIGFILE, $configfile_statements, 'configfile_exist_sql', $filename) || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

sub configfile_db_is_old {
    my ($filename) = @_;
    my $lastMod = ( stat($filename) )[9];

    my $query = db_query_execute(CONFIGFILE, $configfile_statements, 'configfile_exist_old_sql', $filename, $lastMod)
        || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

sub configfile_db_is_new {
    my ($filename) = @_;
    my $lastMod = ( stat($filename) )[9];

    my $query = db_query_execute(CONFIGFILE, $configfile_statements, 'configfile_exist_new_sql', $filename, $lastMod)
        || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

sub configfile_add {
    my ($filename) = @_;
    my $lastMod = ( stat($filename) )[9];

    open my $configfile_fh, '<', $filename;
    my @content = <$configfile_fh>;
    close $configfile_fh;
    db_query_execute(CONFIGFILE, $configfile_statements, 'configfile_add_sql', $filename, join('', @content), $lastMod)
        || return (0);
    return (1);
}

sub configfile_update {
    my ($filename) = @_;
    my $lastMod = ( stat($filename) )[9];

    open my $configfile_fh, '<', $filename;
    my @content = <$configfile_fh>;
    close $configfile_fh;
    db_query_execute(CONFIGFILE, $configfile_statements, 'configfile_update_sql',
        join('', @content), $lastMod, $filename)
        || return (0);
    return (1);
}

sub configfile_view {
    my ($filename) = @_;

    my $query = db_query_execute(CONFIGFILE, $configfile_statements, 'configfile_view_sql', $filename) 
        || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2010 Inverse inc.

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

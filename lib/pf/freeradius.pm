package pf::freeradius;

=head1 NAME

pf::freeradius - FreeRADIUS configuration helper

=cut

=head1 DESCRIPTION

pf::freeradius helps with some configuration aspects of FreeRADIUS

=head1 CONFIGURATION AND ENVIRONMENT

FreeRADIUS' sql.conf and radiusd.conf should be properly configured to have the autoconfiguration benefit.
Reads the following configuration file: F<conf/switches.conf>.

=cut

# TODO move this file into the pf::services package as pf::services::freeradius.
# But first some database handling must be rewritten to depend on coderef instead of symbolic references.
use strict;
use warnings;

use Carp;
use Log::Log4perl;
use Readonly;
use List::MoreUtils qw(natatime);
use Time::HiRes qw(time);

use constant FREERADIUS => 'freeradius';
use constant SWITCHES_CONF => '/switches.conf';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        freeradius_db_prepare
        $freeradius_db_prepared

        freeradius_populate_nas_config
    );
}

use pf::config;
use pf::config::cached;
use pf::db;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $freeradius_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $freeradius_statements = {};


=head1 SUBROUTINES

=over

=item freeradius_db_prepare

Prepares all the SQL statements related to this module

=cut

sub freeradius_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::freeradius');
    $logger->debug("Preparing pf::freeradius database queries");
    my $dbh = get_db_handle();
    if($dbh) {

        $freeradius_statements->{'freeradius_delete_all_sql'} = $dbh->prepare(qq[
            TRUNCATE TABLE radius_nas
        ]);

        $freeradius_statements->{'freeradius_delete_expired_sql'} = $dbh->prepare(qq[
            DELETE FROM radius_nas WHERE config_timestamp != ?;
        ]);

        $freeradius_statements->{'freeradius_insert_nas'} = $dbh->prepare(qq[
            INSERT INTO radius_nas (
                nasname, shortname, secret, description
            ) VALUES (
                ?, ?, ?, ?
            )
        ]);

        $freeradius_db_prepared = 1;
    }
}

=item _delete_all_nas

Empties the radius_nas table

=cut

sub _delete_all_nas {
    my $logger = Log::Log4perl::get_logger('pf::freeradius');
    $logger->debug("emptying radius_nas table");

    db_query_execute(FREERADIUS, $freeradius_statements, 'freeradius_delete_all_sql')
        || return 0;;
    return 1;
}

sub _delete_expired {
    my ($timestamp) = @_;
    my $logger = Log::Log4perl::get_logger('pf::freeradius');
    $logger->debug("emptying radius_nas table");

    db_query_execute(FREERADIUS, $freeradius_statements, 'freeradius_delete_expired_sql', $timestamp)
        || return 0;;
    return 1;
}

=item _insert_nas_bulk

Add a new NAS (FreeRADIUS client) record

=cut

sub _insert_nas_bulk {
    my (@rows) = @_;
    my $logger = Log::Log4perl::get_logger('pf::freeradius');
    return 0 unless @rows;
    my $row_count = @rows;
    my $sql = "REPLACE INTO radius_nas ( nasname, shortname, secret, description, config_timestamp) VALUES ( ?, ?, ?, ?, ?)" . ",( ?, ?, ?, ?, ?)" x ($row_count -1)    ;
    $freeradius_statements->{'freeradius_insert_nas_bulk'} = $sql;

    db_query_execute(
        FREERADIUS, $freeradius_statements, 'freeradius_insert_nas_bulk', map  { @$_ } @rows
    ) || return 0;
    return 1;
}

=item _insert_nas

Add a new NAS (FreeRADIUS client) record

=cut

sub _insert_nas {
    my ($nasname, $shortname, $secret, $description) = @_;
    my $logger = Log::Log4perl::get_logger('pf::freeradius');

    db_query_execute(
        FREERADIUS, $freeradius_statements, 'freeradius_insert_nas', $nasname, $shortname, $secret, $description
    ) || return 0;
    return 1;
}

=item freeradius_populate_nas_config

Populates the radius_nas table with switches in switches.conf.

=cut

# First, we aim at reduced complexity. I prefer to dump and reload than to deal with merging config vs db changes.
sub freeradius_populate_nas_config {
    my $logger = Log::Log4perl::get_logger('pf::freeradius');
    return unless db_ping;
    my ($switch_config,$timestamp) = @_;
    my %skip = (default => undef, '127.0.0.1' => undef );
    my $radiusSecret;
    my @switches = grep {
            !exists $skip{$_}
          && defined( $radiusSecret = $switch_config->{$_}{radiusSecret} )
          && $radiusSecret =~ /\S/
    } keys %$switch_config;
    return unless @switches;
    unless (defined $timestamp ) {
        $timestamp = int (time * 1000000);
    }

    my $it = natatime 100,@switches;
    while (my @ids = $it->() ) {
        my @rows = map {
            my $data = $switch_config->{$_};
            [ $_, $_, $data->{radiusSecret}, $_ . " (" . $data->{'type'} .")", $timestamp ]
        } @ids;
        # insert NAS
        _insert_nas_bulk( @rows );
    }
    _delete_expired($timestamp);
}

=back

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

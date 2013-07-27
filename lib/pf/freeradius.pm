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
#use pf::ConfigStore::SwitchOverlay;

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

    $freeradius_statements->{'freeradius_delete_all_sql'} = get_db_handle()->prepare(qq[
        DELETE FROM radius_nas
    ]);

    $freeradius_statements->{'freeradius_insert_nas'} = get_db_handle()->prepare(qq[
        INSERT INTO radius_nas (
            nasname, shortname, secret, description
        ) VALUES (
            ?, ?, ?, ?
        )
    ]);

    $freeradius_db_prepared = 1;
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
    my ($switch_config) = @_;

    if (!_delete_all_nas()) {
        $logger->info("Problem emptying FreeRADIUS nas clients table.");
    }

    foreach my $switch (keys %$switch_config) {

        # we skip the 'default' entry or the local switch
        if ($switch eq 'default' || $switch eq '127.0.0.1') { next; }

        my $sw_radiussecret = $switch_config->{$switch}{'radiusSecret'};

        # skipping unless switch's radiusSecret exists and is not all whitespace
        unless (defined $sw_radiussecret && $sw_radiussecret =~ /\S/ ) {
            $logger->debug("No RADIUS secret for switch: $switch FreeRADIUS configuration skipped");
            next;
        }

        # insert NAS
        _insert_nas( $switch, $switch, $sw_radiussecret, $switch . " (" . $switch_config->{$switch}{'type'} .")");
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

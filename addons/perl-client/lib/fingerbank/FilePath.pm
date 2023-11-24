package fingerbank::FilePath;

=head1 NAME

fingerbank::FilePath

=head1 DESCRIPTION

File paths and static parameters

=cut

use strict;
use warnings;

use File::Spec::Functions;
use Readonly;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        $INSTALL_PATH
        $CONF_FILE
        $CONFIG_DEFAULTS_FILE
        $CONFIG_DOC_FILE
        $LOG_CONF_FILE
        $LOG_FILE
        $LOCAL_DB_FILE
        $UPSTREAM_DB_FILE
        $COMBINATION_MAP_FILE
        $COLLECTOR_ENDPOINTS_DATA_FILE
        $COLLECTOR_IP_MAPS_FILE
        $COLLECTOR_ENDPOINTS_CACHE_FILE
        %SCHEMA_DBS
    );
}

=head1 FILE PATHS

=over

=item $INSTALL_PATH

=item $CONF_FILE

=item $CONFIG_DEFAULTS_FILE

=item $CONFIG_DOC_FILE

=item $LOG_CONF_FILE

=item $LOG_FILE

=item $LOCAL_DB_FILE

=item $UPSTREAM_DB_FILE

=cut

our $INSTALL_PATH          = '/usr/local/fingerbank/';
our $CONF_FILE             = catfile($INSTALL_PATH, 'conf/fingerbank.conf');
our $CONFIG_DEFAULTS_FILE  = catfile($INSTALL_PATH, 'conf/fingerbank.conf.defaults');
our $CONFIG_DOC_FILE       = catfile($INSTALL_PATH, 'conf/fingerbank.conf.doc');
our $LOG_CONF_FILE         = catfile($INSTALL_PATH, 'conf/log.conf');
Readonly::Scalar our $LOG_FILE              => catfile($INSTALL_PATH, 'logs/fingerbank.log');
Readonly::Scalar our $LOCAL_DB_FILE         => catfile($INSTALL_PATH, 'db/fingerbank_Local.db');
Readonly::Scalar our $UPSTREAM_DB_FILE      => catfile($INSTALL_PATH, 'db/fingerbank_Upstream.db');
Readonly::Scalar our $COMBINATION_MAP_FILE  => catfile($INSTALL_PATH, 'db/fingerbank_Combination_Map.json');
Readonly::Scalar our $COLLECTOR_ENDPOINTS_DATA_FILE  => catfile($INSTALL_PATH, 'db/collector_endpoints.db');
Readonly::Scalar our $COLLECTOR_IP_MAPS_FILE  => catfile($INSTALL_PATH, 'db/collector_ip_maps.db');
Readonly::Scalar our $COLLECTOR_ENDPOINTS_CACHE_FILE  => catfile($INSTALL_PATH, 'db/collector_endpoints_cache.db');

our %SCHEMA_DBS = (
    Local => $LOCAL_DB_FILE,
    Upstream => $UPSTREAM_DB_FILE,
);

Readonly::Array our @PATHS => (
    $INSTALL_PATH, 
    $INSTALL_PATH . 'conf',
    $INSTALL_PATH . 'db',
    $INSTALL_PATH . 'logs',
);

Readonly::Array our @FILES => (
    $CONF_FILE,
    $CONFIG_DEFAULTS_FILE,
    $CONFIG_DOC_FILE,
    $LOG_CONF_FILE,
    $LOCAL_DB_FILE,
    $UPSTREAM_DB_FILE,
    $INSTALL_PATH . 'db/upgrade.pl',
    $LOG_FILE,
);

=back

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

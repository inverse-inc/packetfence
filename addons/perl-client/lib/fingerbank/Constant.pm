package fingerbank::Constant;

=head1 NAME

fingerbank::Constant

=head1 DESCRIPTION

Constants used in the code to make it more readable.

=cut

use strict;
use warnings;

use Readonly;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        $FALSE $TRUE 
        $YES $NO 
        $FINGERBANK_USER 
        $DEFAULT_BACKUP_RETENTION 
        $DEFAULT_SCORE
        $SQLITE_DB_TYPE
        $LOCAL_SCHEMA
        $UPSTREAM_SCHEMA
        $ALL_SCHEMAS_KW
    );
}

=head1 CONSTANTS

=over

=item $VERSION

=item $FALSE

=item $TRUE

=item $YES

=item $NO

=cut

Readonly::Scalar our $VERSION     => "4.3.2";
Readonly::Scalar our $FALSE       => 0;
Readonly::Scalar our $TRUE        => 1;
Readonly::Scalar our $YES         => 'yes';
Readonly::Scalar our $NO          => 'no';

=back

=head1 QUERY PARAMETERS

=over

=item $DHCP_FINGERPRINT

=item $DHCP_VENDOR

=item $USER_AGENT

=item $MAC_VENDOR

=cut

Readonly::Scalar our $DHCP_FINGERPRINT  => 'DHCP_Fingerprint';
Readonly::Scalar our $DHCP_VENDOR       => 'DHCP_Vendor';
Readonly::Scalar our $DHCP6_FINGERPRINT => 'DHCP6_Fingerprint';
Readonly::Scalar our $DHCP6_ENTERPRISE  => 'DHCP6_Enterprise';
Readonly::Scalar our $USER_AGENT        => 'User_Agent';
Readonly::Scalar our $MAC_VENDOR        => 'MAC_Vendor';

=item @QUERY_PARAMETERS

An array containing all the query parameters

=cut

Readonly::Array our @QUERY_PARAMETERS => (
    $DHCP_FINGERPRINT,
    $DHCP_VENDOR,
    $USER_AGENT,
    $MAC_VENDOR,
    $DHCP6_FINGERPRINT,
    $DHCP6_ENTERPRISE,
);

=item %PARENT_IDS

A hash containing the parent ids for the base devices

=cut

Readonly::Hash our %PARENT_IDS => (
    WINDOWS => 1,
    MACOS => 2,
    LINUX => 5,
    ANDROID => 33453,
    IOS => 33450,
    WINDOWS_PHONE => 33507,
    BLACKBERRY => 33471,
);

Readonly::Hash our %DEVICE_CLASS_IDS => (
    %PARENT_IDS,
);

Readonly::Array our @DEVICE_CLASS_LOOKUP_ORDER => (
    (grep { $_ ne "WINDOWS" } keys(%DEVICE_CLASS_IDS)),
    "WINDOWS",
);

Readonly::Hash our %MOBILE_IDS => (
    ANDROID => $PARENT_IDS{ANDROID},
    IOS => $PARENT_IDS{IOS},
    WINDOWS_PHONE => $PARENT_IDS{WINDOWS_PHONE},
    BLACKBERRY => $PARENT_IDS{BLACKBERRY},
    WATCHOS => 33451,
    PHONE_TABLET_WEARABLE => 11,
    PALMOS => 204,
    WEBOS => 33481,
);

Readonly::Scalar our $HARDWARE_MANUFACTURER_ID => 16861;

=item $FINGERBANK_USER

The OS user for Fingerbank

=cut

Readonly our $FINGERBANK_USER => "fingerbank";

=item $FILE_PERMISSIONS

The octal format of file permissions

=cut

Readonly our $FILE_PERMISSIONS => 0664;

=item $PATH_PERMISSIONS

The octal format of path permissions

=cut

Readonly our $PATH_PERMISSIONS => 0775;

=item $DEFAULT_BACKUP_RETENTION

The amount of backups to keep by default in the file cleanup

=cut

Readonly our $DEFAULT_BACKUP_RETENTION => 5;

=item $DEFAULT_SCORE

The score that is given by default on any match

=cut

Readonly our $DEFAULT_SCORE => 1;

=item $SQLITE_DB_TYPE

=cut

Readonly our $SQLITE_DB_TYPE => "SQLite";

=item $LOCAL_SCHEMA

=cut

Readonly our $LOCAL_SCHEMA => "Local";

=item $UPSTREAM_SCHEMA

=cut

Readonly our $UPSTREAM_SCHEMA => "Upstream";

=item $ALL_SCHEMAS_KW

Keyword to be used as a schema name to represent all the schemas.

=cut

Readonly our $ALL_SCHEMAS_KW => 'All';

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

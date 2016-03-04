package pf::constants::trigger;
=head1 NAME

pf::constants::trigger add documentation

=cut

=head1 DESCRIPTION

pf::constants::trigger

=cut

use strict;
use warnings;
use base qw(Exporter);
use Readonly;
use pf::file_paths;
use pf::metascan();
use File::Slurp;

our @EXPORT_OK = qw(
        $TRIGGER_TYPE_ACCOUNTING $TRIGGER_TYPE_DETECT $TRIGGER_TYPE_INTERNAL $TRIGGER_TYPE_MAC $TRIGGER_TYPE_NESSUS $TRIGGER_TYPE_OPENVAS $TRIGGER_TYPE_METASCAN $TRIGGER_TYPE_OS $TRIGGER_TYPE_SOH $TRIGGER_TYPE_USERAGENT $TRIGGER_TYPE_VENDORMAC $TRIGGER_TYPE_PROVISIONER @VALID_TRIGGER_TYPES
        $TRIGGER_ID_PROVISIONER
        $TRIGGER_MAP
);

# Violation trigger types
Readonly::Scalar our $TRIGGER_TYPE_ACCOUNTING => 'accounting';
Readonly::Scalar our $TRIGGER_TYPE_DETECT => 'detect';
Readonly::Scalar our $TRIGGER_TYPE_INTERNAL => 'internal';
Readonly::Scalar our $TRIGGER_TYPE_MAC => 'mac';
Readonly::Scalar our $TRIGGER_TYPE_NESSUS => 'nessus';
Readonly::Scalar our $TRIGGER_TYPE_OPENVAS => 'openvas';
Readonly::Scalar our $TRIGGER_TYPE_METASCAN => 'metascan';
Readonly::Scalar our $TRIGGER_TYPE_OS => 'os';
Readonly::Scalar our $TRIGGER_TYPE_SOH => 'soh';
Readonly::Scalar our $TRIGGER_TYPE_SURICATA_EVENT => 'suricata_event';
Readonly::Scalar our $TRIGGER_TYPE_USERAGENT => 'useragent';
Readonly::Scalar our $TRIGGER_TYPE_VENDORMAC => 'vendormac';
Readonly::Scalar our $TRIGGER_TYPE_PROVISIONER => 'provisioner';
Readonly::Scalar our $TRIGGER_ID_PROVISIONER => 'check';

Readonly::Scalar our $SURICATA_CATEGORIES => sub {
    my %map;
    my @categories = split("\n", read_file($suricata_categories_file));
    foreach my $category (@categories){
        $map{$category} = $category;
    }
    return \%map;
}->();

Readonly::Scalar our $TRIGGER_MAP => {
  $TRIGGER_TYPE_INTERNAL => {
    "1100010" => "Rogue DHCP detection",
    "new_dhcp_info" => "DHCP packet received",
    "hostname_change" => "Hostname changed",
    "parking_detected" => "Parking detected",
  },
  $TRIGGER_TYPE_PROVISIONER => {
    $TRIGGER_ID_PROVISIONER => "Check status",
  },
  $TRIGGER_TYPE_SURICATA_EVENT => $SURICATA_CATEGORIES,
  $TRIGGER_TYPE_METASCAN => $pf::metascan::METASCAN_RESULT_IDS,
};

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


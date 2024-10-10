package pf::constants::switch_acls;

=head1 NAME

pf::constants::switch_acls - 

=cut

=head1 DESCRIPTION

pf::constants::switch_acls



=cut

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(%ACLsSupports);

our %ACLsSupports;

%ACLsSupports = (
                  'AccessListBasedEnforcement' => {
                                                    'Alcatel' => 1,
                                                    'Aruba::2930M' => 1,
                                                    'Aruba::5400' => 1,
                                                    'Aruba::CX' => 1,
                                                    'Brocade' => 1,
                                                    'Cisco::ASA' => 1,
                                                    'Cisco::Catalyst_2970' => 1,
                                                    'Cisco::Catalyst_3550' => 1,
                                                    'Cisco::Catalyst_3560' => 1,
                                                    'Cisco::Catalyst_3750' => 1,
                                                    'Cisco::Catalyst_4500' => 1,
                                                    'Cisco::Catalyst_6500' => 1,
                                                    'Cisco::Cisco_IOS_12_x' => 1,
                                                    'Cisco::Cisco_IOS_15_0' => 1,
                                                    'Cisco::Cisco_IOS_15_5' => 1,
                                                    'Cisco::SG300' => 1,
                                                    'Dell::N1500' => 1,
                                                    'Extreme::EXOS' => 1,
                                                    'Fortinet::FortiSwitch' => 1,
                                                    'Huawei::S5710' => 1,
                                                    'Juniper::EX2200' => 1,
                                                    'Juniper::EX2200_v15' => 1,
                                                    'Juniper::EX2300' => 1,
                                                    'Mikrotik' => 1,
                                                    'Pica8' => 1
                                                  },
                  'DownloadableListBasedEnforcement' => {
                                                          'Cisco::ASA' => 1,
                                                          'Cisco::Cisco_IOS_15_5' => 1,
                                                          'Dell::N1500' => 1
                                                        }
                );



=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

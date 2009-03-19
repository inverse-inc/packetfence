#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::Cisco::Aironet_1130;

=head1 NAME

pf::SNMP::Cisco::Aironet_1130 - Object oriented module to access SNMP enabled Cisco Aironet 1130 APs

=head1 SYNOPSIS

The pf::SNMP::Cisco::Aironet_1130 module implements an object oriented interface
to access SNMP enabled Cisco Aironet_1130 APs.

This modules extends pf::SNMP::Cisco::Aironet

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;

use base ('pf::SNMP::Cisco::Aironet');

1;

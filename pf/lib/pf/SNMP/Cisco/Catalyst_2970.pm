#
# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::Cisco::Catalyst_2970;

=head1 NAME

pf::SNMP::Cisco::Catalyst_2970 - Object oriented module to access SNMP enabled Cisco Catalyst 2970 switches


=head1 SYNOPSIS

The pf::SNMP::Cisco::Catalyst_2970 module implements an object oriented interface
to access SNMP enabled Cisco::Catalyst_2970 switches.

This modules extends pf::SNMP::Cisco::Catalyst_2960

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;

use base ('pf::SNMP::Cisco::Catalyst_2960');

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

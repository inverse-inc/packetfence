#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::HP::Procurve_2600;

=head1 NAME

pf::SNMP::HP::Procurve_2600 - Object oriented module to access SNMP enabled HP Procurve 2600 switches


=head1 SYNOPSIS

The pf::SNMP::HP::Procurve_2600 module implements an object 
oriented interface to access SNMP enabled HP Procurve 2600 switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::HP');

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

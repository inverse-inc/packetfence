#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::Nortel::BayStack470;

=head1 NAME

pf::SNMP::Nortel::BayStack470 - Object oriented module to access SNMP enabled Nortel BayStack470 switches


=head1 SYNOPSIS

The pf::SNMP::Nortel::BayStack470 module implements an object 
oriented interface to access SNMP enabled Nortel::BayStack470 switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::Nortel');


1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

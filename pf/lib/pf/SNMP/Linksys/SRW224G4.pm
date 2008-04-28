#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::Linksys::SRW224G4;

=head1 NAME

pf::SNMP::Linksys::SRW224G4 - Object oriented module to access SNMP enabled Linksys SRW224G4 switches


=head1 SYNOPSIS

The pf::SNMP::Linksys::SRW224G4 module implements an object 
oriented interface to access SNMP enabled Linksys SRW224G4 switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::Linksys');


1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

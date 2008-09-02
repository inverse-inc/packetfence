# Copyright 2008 Treker Chen treker.chen@gmail.com
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::Dlink::DES_3526;

=head1 NAME

pf::SNMP::Dlink::DES_3526 - Object oriented module to access SNMP enabled Dlink DES 3526 switches


=head1 SYNOPSIS

The pf::SNMP::Dlink::DES_3526 module implements an object oriented interface
to access SNMP enabled Dlink DES 3526 switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::Dlink');

1;
# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

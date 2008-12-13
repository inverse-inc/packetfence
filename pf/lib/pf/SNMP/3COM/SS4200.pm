#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
# *** SETVLAN NOT WORK WITH DEFAULT VLAN ID 1 ***
#

package pf::SNMP::3COM::SS4200;

=head1 NAME

pf::SNMP::3COM::SS4200 - Object oriented module to access SNMP enabled 3COM Huawei SuperStack 3 Switch - 4200 switches


=head1 SYNOPSIS

The pf::SNMP::3COM::SS4200 module implements an object 
oriented interface to access SNMP enabled 
3COM Huawei SuperStack 3 Switch - 4200 switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;

use lib '/usr/local/pf/lib';
use base ('pf::SNMP::3COM::SS4500');

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

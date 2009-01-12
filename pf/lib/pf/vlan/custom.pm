#
# Copyright 2006-2009 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::vlan::custom;

=head1 NAME

pf::vlan::custom - Object oriented module for VLAN isolation oriented functions 


=head1 SYNOPSIS

The pf::vlan::custom module implements VLAN isolation 
oriented functions.

This modules extends pf::vlan

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;

use base ('pf::vlan');

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::3COM::NJ220;

=head1 NAME

pf::SNMP::3COM::NJ220 - Object oriented module to access SNMP enabled 3COM NJ220 switches


=head1 SYNOPSIS

The pf::SNMP::3COM::NJ220 module implements an object 
oriented interface to access SNMP enabled 3COM NJ220 switches.

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::3COM');

sub getVersion {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->info("we don't know how to determine the version through SNMP !");
    return '2.0.13';
}
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

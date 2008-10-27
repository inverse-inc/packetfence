#
# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
#

package pf::SNMP::Intel;

=head1 NAME

pf::SNMP::Intel - Object oriented module to access SNMP enabled Intel switches


=head1 SYNOPSIS

The pf::SNMP::Intel module implements an object oriented interface
to access SNMP enabled Intel switches.

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use Log::Log4perl;

sub parseTrap {
    my ($this, $trapString) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger(ref($this));
    if ($trapString =~ /^BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = INTEGER: \d+ END VARIABLEBINDINGS$/) {
        $trapHashRef->{'trapType'} = (($1 == 2) ? "down" : "up");
        $trapHashRef->{'trapIfIndex'} = $2;
    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub getAlias {
    my ($this, $ifIndex) = @_;
    return "This function is not supported by Intel switches";
}

sub setAlias {
    my ($this, $ifIndex, $alias) = @_;
    return 1;
}

1;


# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

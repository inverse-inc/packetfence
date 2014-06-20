package pf::Switch::Avaya::ERS4000Stack;

=head1 NAME

pf::Switch::Avaya::ERS4000 - Object oriented module to access SNMP enabled Avaya ERS 4000 switches

=head1 SYNOPSIS

The pf::Switch::Avaya::ERS4000 module implements an object 
oriented interface to access SNMP enabled Avaya::ERS4000 switches.

=head1 STATUS

This module is currently only a placeholder, see pf::Switch::Avaya.

=cut

use strict;
use warnings;

use pf::Switch::constants;
use Log::Log4perl;
use Net::SNMP;

use base ('pf::Switch::Avaya');

sub supportsRadiusVoip { return $SNMP::TRUE; }
sub supportsWiredMacAuth { return $SNMP::TRUE; }

sub description { 'Avaya ERS 4000 Stacked Series' }

sub getBoardPortFromIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_ifDesc = '1.3.6.1.2.1.31.1.1.1.1';
    my $result = $this->{_sessionRead}->get_request( -varbindlist => ["$OID_ifDesc.$ifIndex"] );
    if ($result->{"$OID_ifDesc.$ifIndex"} =~ /Slot:\s(\d+)\sPort:\s(\d+)/) {
        return ($1,$2);
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

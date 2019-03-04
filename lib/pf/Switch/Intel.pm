package pf::Switch::Intel;

=head1 NAME

pf::Switch::Intel - Object oriented module to access SNMP enabled Intel switches

=head1 SYNOPSIS

The pf::Switch::Intel module implements an object oriented interface
to access SNMP enabled Intel switches.

=cut

use strict;
use warnings;

use base ('pf::Switch');

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;
    if ( $trapString
        =~ /^BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = INTEGER: \d+ END VARIABLEBINDINGS$/
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub getAlias {
    my ( $self, $ifIndex ) = @_;
    return "This function is not supported by Intel switches";
}

sub setAlias {
    my ( $self, $ifIndex, $alias ) = @_;
    return 1;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

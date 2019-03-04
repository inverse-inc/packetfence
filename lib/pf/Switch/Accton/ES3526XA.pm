package pf::Switch::Accton::ES3526XA;

=head1 NAME

pf::Switch::Accton::ES3526XA - Object oriented module to access SNMP enabled Accton ES3526XA switches

=head1 SYNOPSIS

The pf::Switch::Accton::ES3526XA module implements an object oriented interface
to access SNMP enabled Accton::ES3526XA switches.

The minimum required firmware version is 2.3.3.5.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Net::SNMP;
use base ('pf::Switch::Accton');

sub description { 'Accton ES3526XA' }

sub getMinOSVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    return '2.3.3.5';
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

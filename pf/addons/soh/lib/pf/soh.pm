package pf::soh;

=head1 NAME

pf::soh - A module to evaluate and respond to SoH requests

=head1 SYNOPSIS

This module contains the infrastructure necessary to evaluate
statement-of-health (SoH) requests tunnelled inside 802.1x/EAP
authentication negotiations.

FreeRADIUS passes SoH requests through a separate virtual server, which
uses a perl module to forward the requests via SOAP to pf::WebAPI, which
instantiates a pf::soh object to generate a suitable response.

The methods in pf::soh can be overriden in pf::soh::custom.

=cut

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;

use pf::config;
use pf::db;
use pf::radius::constants;

our $VERSION = 1.0;

=head1 SUBROUTINES

=over

=item * new - returns a new pf::soh object

=cut

sub new {
    my ($class) = @_;

    return bless {}, $class;
}

=item * authorize - handles the SoH request

Takes a RADIUS request containing synthetic SoH attributes, forwarded
through the SoH virtual server, decides how to handle it based on the
filters created by the user, and returns an appropriate response.

=cut

# XXX This is the stub version XXX
sub authorize {
    my $self = shift;

    return [$RADIUS::RLM_MODULE_OK];
}

=back

=head1 AUTHOR

Abhijit Menon-Sen <amenonsen@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

=cut

1;

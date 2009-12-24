package pf::radius;

=head1 NAME

pf::radius - Module that deals with everything radius related

=head1 SYNOPSIS

The pf::radius module contains the functions necessary for answering radius queries.
Radius is the network access component known as AAA used in 802.1x, MAC authentication, 
MAC authentication bypass (MAB), etc. This module acts as a proxy between our radius 
perl module's SOAP requests (rlm_perl_packetfence.pl) and PacketFence core modules.

All the behavior contained here can be overridden in lib/pf/radius/custom.pm.

=cut

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;
use pf::config;

=head1 SUBROUTINES

=over

=cut

=item * new - get a new instance of the radius object
 
=cut
sub new {
    my $logger = Log::Log4perl::get_logger("pf::radius");
    $logger->debug("instantiating new pf::radius object");
    my ( $class, %argv ) = @_;
    my $this = bless {}, $class;
    return $this;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009 Inverse inc.

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

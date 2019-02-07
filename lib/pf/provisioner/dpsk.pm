package pf::provisioner::dpsk;
=head1 NAME

pf::provisioner::dpsk allow to have a html page that present the psk and the ssid to use


=cut

=head1 DESCRIPTION

pf::provisioner::dpsk

=cut

use strict;
use warnings;
use List::MoreUtils qw(any);
use Crypt::GeneratePassword qw(word);
use pf::person;

use Moo;
extends 'pf::provisioner::mobileconfig';


=head1 METHODS

=head2 authorize

never authorize user

=cut

sub authorize { 0 };

=head2 oses

The oses

=cut

has oses => (is => 'rw');

=head2 ssid

The ssid broadcast name

=cut

has ssid => (is => 'rw');

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


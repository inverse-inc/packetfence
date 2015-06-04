package pf::provisioner::android;
=head1 NAME

pf::provisioner::android add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::android

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner::mobileconfig';

=head1 Atrributes

=head2 oses

The set the default OS Andriod

=cut

# Will always ignore the oses parameter provided and use [Generic Android]
has 'oses' => (is => 'ro', default => sub { ['Generic Android'] }, coerce => sub { ['Generic Android'] });

=head2 profile_template

The template to use for profile

=cut

has profile_template => (is => 'rw', default => sub { "windows-profile.xml" });

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

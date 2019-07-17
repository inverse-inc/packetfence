#!/usr/bin/perl

=head1 NAME

release.pl

=cut

=head1 DESCRIPTION

Tries to release the user from the parking state.
Notifies of the result through back-on-network.html and max-attempts.html

=cut

use strict;
use warnings;
use lib '/usr/local/pf/lib';

use CGI qw(:standard);

use pf::parking;

my $ip = $ENV{REMOTE_ADDR};
my $mac = pf::ip4log::ip2mac($ip);

if(pf::parking::unpark($mac, $ip)){
    print redirect("/back-on-network.html");
}
else {
    print redirect("/max-attempts.html");
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
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.

=cut

1;

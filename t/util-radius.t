#!/usr/bin/perl
=head1 NAME

util-radius.t

=head1 DESCRIPTION

pf::util::radius module tests

=cut

use strict;
use warnings;
use diagnostics;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 7;
use Test::NoWarnings;

=head1 Tests

=cut

use_ok('pf::util::radius');

# The CoA and Disconnect entries of the RADIUS audit log use the format of the
# radius audit log flush job (#8124)
is(
    pf::util::radius::format_audit_log_attributes(['Cisco-AVPair', 'subscriber:command=reauthenticate']),
    'Cisco-AVPair =3D =22subscriber:command=3Dreauthenticate=22',
    "an = in a value is escaped"
);

is(
    pf::util::radius::format_audit_log_attributes(['NAS-IP-Address', '10.0.0.1'], ['Calling-Station-Id', '00-11-22-33-44-55']),
    'NAS-IP-Address =3D =2210.0.0.1=22=2C=0ACalling-Station-Id =3D =2200-11-22-33-44-55=22',
    "attributes are separated by a comma and a new line"
);

is(
    pf::util::radius::format_audit_log_attributes(['Message-Authenticator', "\x01\xff\x00"]),
    'Message-Authenticator =3D =220x01ff00=22',
    "a binary value is written in hexadecimal"
);

is(
    pf::util::radius::format_audit_log_attributes(['Reply-Message', undef]),
    'Reply-Message =3D =22=22',
    "an undefined value is empty"
);

like(
    pf::util::radius::format_audit_log_attributes(['Filter-Id', "a+b%c\"d'e"], ['User-Name', "caf\x{e9}"]),
    qr{^[A-Za-z0-9\@.\-_: /=]*$},
    "only safe characters reach the database"
);

# TODO: we have integration tests in stress-test/ {coa-calls.pl, coa-server.pl} for perform_dynauth.

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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


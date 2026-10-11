#!/usr/bin/perl

=head1 NAME

pfdns

=head1 DESCRIPTION

Unit tests for pf::services::manager::pfdns

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}
use Test::More tests => 7;
use File::Temp qw(tempfile);
use pf::services::manager::pfdns;

my $content = <<'CONF';
.:54 {
    forward . /etc/resolv.conf {
        prefer_udp
    }
}
.:53 {
    pfdns {
    }
    forward example.com. 10.0.0.1
    forward . 10.0.0.53 {
        network_source 192.168.1.0/24
    }
    # Default to system resolv.conf file
    forward . /etc/resolv.conf
    errors
}
CONF
my $out = pf::services::manager::pfdns::remove_resolv_conf_forwards($content);
unlike($out, qr{/etc/resolv\.conf\s*(\{|\n)}, "resolv.conf forwards removed");
like($out, qr{forward example\.com\. 10\.0\.0\.1}, "domain forward kept");
like($out, qr{forward \. 10\.0\.0\.53 \{\n\s+network_source}, "inline forward kept");
like($out, qr{pfdns \{\n\s+\}}, "pfdns block kept");

sub resolv { my ($fh, $f) = tempfile(); print $fh $_[0]; close $fh; $pf::services::manager::pfdns::RESOLV_CONF = $f; pf::services::manager::pfdns::has_resolv_nameservers() }
is(resolv("# empty\nsearch example.com\n"), 0, "no nameserver");
is(resolv("nameserver 2001:db8::53\n"), 1, "ipv6 nameserver");
$pf::services::manager::pfdns::RESOLV_CONF = '/nonexistent';
is(pf::services::manager::pfdns::has_resolv_nameservers(), 0, "missing file");

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

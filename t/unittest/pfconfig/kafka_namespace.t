#!/usr/bin/perl

=head1 NAME

kafka_namespace

=head1 DESCRIPTION

pfconfig::namespaces::config::Kafka::build_child: auths are always built,
even when kafka.conf has no [iptables] section (e.g. after a partial PATCH
of auths only).

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 7;
use Test::NoWarnings;
use pfconfig::namespaces::config::Kafka;

# A config without an [iptables] section
my $ns = bless {
    cfg => {
        admin     => { user => 'admin', pass => 'admin-pass' },
        'auth u1' => { pass => 'pass1' },
    }
}, 'pfconfig::namespaces::config::Kafka';

my $result = $ns->build_child();

ok(exists $result->{auths},         'auths is built without an [iptables] section');
is(scalar @{$result->{auths}}, 2,   'admin + one auth entry');
is($result->{auths}[0]{user}, 'admin', 'admin is first');
is($result->{auths}[1]{user}, 'u1',    'auth u1 is included');
ok(!exists $result->{'auth u1'},    'raw auth key is removed');
ok(!exists $result->{iptables},     'no iptables key when section is absent');

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

1;

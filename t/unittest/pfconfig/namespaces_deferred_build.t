#!/usr/bin/perl

=head1 NAME

pfconfig namespaces deferred build

=cut

=head1 DESCRIPTION

Regression test for the pfconfig reload memory leak.

The manager constructs every namespace on each expire (via get_namespace) just
to read its child_resources. A handful of resource namespaces used to run a
full config build() inside init(), so each C<pfcmd pfconfig reload> rebuilt
those configs and leaked memory (the tied pf::IniFiles reads never fully free).

Construction (new -> init) must therefore stay cheap: the heavy build work must
happen only in build(). This test asserts init() does not populate the
build-only attributes.

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use setup_test_config;
}

use Test::More tests => 7;
use Test::NoWarnings;

use_ok("pfconfig::namespaces::resource::network_config");
use_ok("pfconfig::namespaces::resource::accounting_triggers");
use_ok("pfconfig::namespaces::resource::bandwidth_expired_security_events");

# A cheap init() must not touch the cache, so a bare fake cache is enough here.
my $cache = bless {}, "pfconfig::manager";

my $nc = pfconfig::namespaces::resource::network_config->new($cache, "");
ok(
    !exists $nc->{cluster_resource} && !exists $nc->{config_pf},
    "network_config init() does not build its dependencies (deferred to build)"
);

my $at = pfconfig::namespaces::resource::accounting_triggers->new($cache);
ok(
    !exists $at->{_engine},
    "accounting_triggers init() does not construct the SecurityEvent engine"
);

my $bw = pfconfig::namespaces::resource::bandwidth_expired_security_events->new($cache);
ok(
    !exists $bw->{_engine},
    "bandwidth_expired_security_events init() does not construct the SecurityEvent engine"
);

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

#!/usr/bin/perl

=head1 NAME

radiusd_child_degraded

=head1 DESCRIPTION

Unit tests of the generation of the degraded mode of the proxied realms

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 17;
use Test::NoWarnings;

use pf::config;
use pf::services::manager::radiusd_child;

local %pf::config::ConfigRealm = (
    'default' => { eap => 'default' },
    'acme.com' => {
        eap => 'corp',
        radius_auth => 'rad1,rad2',
        radius_degraded => 'enabled',
        radius_degraded_cache_miss => 'reject',
        radius_auth_compute_in_pf => 'enabled',
    },
    'beta.com' => {
        eap => 'default',
        regex => '.*beta\.com$',
        radius_auth => 'rad3',
        radius_degraded => 'enabled',
        radius_degraded_cache_miss => 'compute_in_pf',
        radius_auth_compute_in_pf => 'disabled',
    },
    'gamma.com' => {
        eap => 'default',
        radius_auth => 'rad4',
        radius_degraded => 'enabled',
        radius_degraded_cache_miss => 'accept',
        radius_auth_compute_in_pf => 'disabled',
    },
    'delta.com' => { eap => 'default', radius_auth => 'rad5', radius_degraded => 'disabled' },
    'epsilon.com' => { eap => 'default', radius_degraded => 'enabled' },
);
local @pf::config::ConfigOrderedRealm = ('acme.com', 'beta.com', 'gamma.com', 'delta.com', 'epsilon.com', 'default');

is_deeply(
    [pf::services::manager::radiusd_child::degraded_realms()],
    ['acme.com', 'beta.com', 'gamma.com'],
    "Only the realms proxying the authentication with the degraded mode enabled",
);

is(pf::services::manager::radiusd_child::realm_condition('acme.com'), 'Realm == "acme.com"', "Realm matched by name");
is(pf::services::manager::radiusd_child::realm_condition('beta.com'), 'Realm =~ /.*beta\.com$/', "Realm matched by regex");

my %tags;
pf::services::manager::radiusd_child::generate_degraded_realms(\%tags);
is($tags{degraded_realms}, 3, "Degraded realms counted");
is(
    $tags{degraded_cache},
    'Realm == "acme.com" || Realm =~ /.*beta\.com$/ || Realm == "gamma.com"',
    "The answers of all the degraded realms are cached",
);
like($tags{degraded_cache_miss_reject}, qr/if \( Realm == "acme\.com" \) \{\s+reject/, "Cache miss rejected");
unlike($tags{degraded_cache_miss_reject}, qr/beta|gamma/, "Only the realms rejecting the cache miss");
like($tags{degraded_cache_miss_compute}, qr/Cache-Miss" && \( EAP-Type == TTLS \|\| EAP-Type == PEAP \) && \( Realm =~ \/\.\*beta\\\.com\$\/ \)/, "Cache miss authorized from PacketFence");
unlike($tags{degraded_cache_miss_compute}, qr/acme|gamma/, "Not for the realms already authorized from PacketFence or accepting the cache miss");

my ($choice, $auth_type) = ('', '');
pf::services::manager::radiusd_child::generate_eap_choice(\$choice, \$auth_type, "eap-degraded");
like($choice, qr/if \(Realm =~ \/acme\.com\/\) \{\s+corp-eap-degraded \{/, "Degraded EAP instance of the realm profile");
like($choice, qr/else \{\s+eap-degraded \{/, "Default degraded EAP instance");
unlike($choice, qr/^\s+(corp|eap) \{/m, "No regular EAP instance in degraded mode");
like($auth_type, qr/Auth-Type eap-degraded \{/, "Default degraded EAP Auth-Type");

($choice, $auth_type) = ('', '');
pf::services::manager::radiusd_child::generate_eap_choice(\$choice, \$auth_type);
like($choice, qr/if \(Realm =~ \/acme\.com\/\) \{\s+corp \{/, "Regular EAP instance of the realm profile");
like($choice, qr/else \{\s+eap \{/, "Default regular EAP instance");

local %pf::config::ConfigRealm = ('acme.com' => { eap => 'default', radius_auth => 'rad1' });
local @pf::config::ConfigOrderedRealm = ('acme.com');
%tags = ();
pf::services::manager::radiusd_child::generate_degraded_realms(\%tags);
ok(!$tags{degraded_realms} && $tags{degraded_cache} eq '', "Nothing generated without degraded realm");

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

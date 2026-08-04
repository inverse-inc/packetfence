#!/usr/bin/perl

=head1 NAME

AzureADSource

=head1 DESCRIPTION

unit test for AzureADSource, focused on the device-owner group lookup that
merges a device's own groups with the groups of its registered owner.

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 4;
use Test::MockModule;
use HTTP::Response;
use JSON::MaybeXS qw(encode_json);

use pf::Authentication::Source::AzureADSource;

# Canned Graph API responses keyed by the kind of URL being requested. The
# device is configured to look up its own groups through the devices() path,
# so both the device-groups URL and the registeredOwners URL contain
# "devices(deviceId=" - registeredOwners must therefore be matched first.
my @DEVICE_GROUPS = ({ id => 'g1', displayName => 'DeviceGroupA' }, { id => 'g2', displayName => 'SharedGroup' });
my @OWNER_GROUPS  = ({ id => 'g3', displayName => 'OwnerGroupX' },  { id => 'g2', displayName => 'SharedGroup' });
my @OWNERS        = ({ id => 'owner-123', userPrincipalName => 'owner@example.com' });

# Toggled per-case to simulate a device with no registered owner.
my $owners_empty = 0;

sub graph_response {
    my ($url) = @_;
    my $value;
    if ($url =~ /registeredOwners/) {
        $value = $owners_empty ? [] : [@OWNERS];
    }
    elsif ($url =~ m{/users/}) {
        $value = [@OWNER_GROUPS];
    }
    else {
        $value = [@DEVICE_GROUPS];
    }
    return HTTP::Response->new(200, 'OK', [ 'Content-Type' => 'application/json' ], encode_json({ value => $value }));
}

my $source_mock = Test::MockModule->new('pf::Authentication::Source::AzureADSource');
$source_mock->mock('get_admin_token', sub { return 'faketoken' });

my $ua_mock = Test::MockModule->new('LWP::UserAgent');
$ua_mock->mock('get', sub { my ($self, $url, @rest) = @_; return graph_response($url) });

my %common = (
    id                   => 'test',
    client_id            => 'cid',
    client_secret        => 'secret',
    tenant_id            => 'tid',
    user_groups_url_path => "/v1.0/devices(deviceId='%USERNAME')/memberOf",
);

# Case (a): toggle off -> device groups only, current behavior unchanged.
{
    my $source = pf::Authentication::Source::AzureADSource->new({ %common, lookup_device_owner => 0 });
    is_deeply(
        [ sort $source->get_memberOf('device-id') ],
        [ sort qw(DeviceGroupA SharedGroup) ],
        "toggle off returns only the device's own groups",
    );
}

# Case (b): toggle on -> device + first-owner groups merged and de-duplicated.
{
    my $source = pf::Authentication::Source::AzureADSource->new({ %common, lookup_device_owner => 1 });
    is_deeply(
        [ sort $source->get_memberOf('device-id') ],
        [ sort qw(DeviceGroupA OwnerGroupX SharedGroup) ],
        "toggle on merges device and owner groups, de-duplicating SharedGroup",
    );
}

# Case (c): toggle on but no registered owner -> device groups only.
{
    local $owners_empty = 1;
    my $source = pf::Authentication::Source::AzureADSource->new({ %common, lookup_device_owner => 1 });
    is_deeply(
        [ sort $source->get_memberOf('device-id') ],
        [ sort qw(DeviceGroupA SharedGroup) ],
        "toggle on with no registered owner falls back to device groups only",
    );
}

#This test will run last
use Test::NoWarnings;

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

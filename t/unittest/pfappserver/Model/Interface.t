#!/usr/bin/perl

=head1 NAME

Interface

=head1 DESCRIPTION

unit test for pfappserver::Model::Interface: where each interface type, with or
without additional listening daemons, ends up in pf.conf and networks.conf

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 34;

#This test will running last
use Test::NoWarnings;
use pfappserver::Model::Interface;

{
    # Records the calls setType makes on the pf.conf and networks.conf models
    package StubConfigModel;
    sub new { bless { calls => [], exists => $_[1] }, $_[0] }
    sub update_or_create { my ($self, $id, $data) = @_; push @{$self->{calls}}, [update_or_create => $id, $data]; return (200) }
    sub remove { my ($self, $id) = @_; push @{$self->{calls}}, [remove => $id]; return (200) }
    sub read { my ($self) = @_; return $self->{exists} ? (200, ref $self->{exists} ? $self->{exists} : {}) : (404, "not found") }
    sub commit { return (200) }
    sub calls { map { $_->[0] } @{$_[0]{calls}} }
    sub last_data { my @u = grep { $_->[0] eq 'update_or_create' } @{$_[0]{calls}}; return @u ? $u[-1][2] : undef }
}

sub set_type {
    my ($type) = @_;
    my $models = {
        interface => StubConfigModel->new(1),
        network   => StubConfigModel->new(0),
    };
    my $model = pfappserver::Model::Interface->new(models => $models);
    $model->setType("eth1", {
        type      => $type,
        network   => "192.168.2.0",
        ipaddress => "192.168.2.1",
        netmask   => "255.255.255.0",
    });
    return $models;
}

# [ type, pf.conf type, pf.conf enforcement, networks.conf: written type or undef when removed ]
my @cases = (
    [ "dns-enforcement",          "internal",        "dns",  "dns-enforcement" ],
    [ "dns-enforcement,radius",   "internal,radius", "dns",  "dns-enforcement,radius" ],
    [ "dns-enforcement,dhcp",     "internal",        "dns",  "dns-enforcement,dhcp" ],
    [ "dns-enforcement,portal",   "internal",        "dns",  "dns-enforcement,portal" ],
    [ "vlan-registration,portal", "internal",        "vlan", "vlan-registration,portal" ],
    [ "vlan-isolation,dhcp",      "internal",        "vlan", "vlan-isolation,dhcp" ],
    [ "management",               "management",      undef,  undef ],
    [ "management,portal",        "management,portal", undef, undef ],
    [ "portal",                   "portal",          undef,  undef ],
    [ "dhcp-listener",            "dhcp-listener",   undef,  undef ],
);

for my $case (@cases) {
    my ($type, $pf_type, $pf_enforcement, $network_type) = @$case;
    my $models = set_type($type);
    my $pf = $models->{interface}->last_data;
    is($pf->{type}, $pf_type, "$type: pf.conf type");
    is($pf->{enforcement}, $pf_enforcement, "$type: pf.conf enforcement");
    if (defined $network_type) {
        is(($models->{network}->last_data // {})->{type}, $network_type, "$type: written to networks.conf");
    } else {
        is_deeply([$models->{network}->calls], ["remove"], "$type: kept out of networks.conf");
    }
}

# getType falls back on pf.conf when networks.conf has no entry for the interface
for my $case (
    [ { type => "internal", enforcement => "dns" },        "dns-enforcement" ],
    [ { type => "internal,radius", enforcement => "dns" }, "dns-enforcement,radius" ],
    [ { type => "internal", enforcement => "vlan" },       "other" ],
) {
    my ($pfconf, $expected) = @$case;
    my $model = pfappserver::Model::Interface->new(models => {
        interface => StubConfigModel->new($pfconf),
        network   => StubConfigModel->new(0),
    });
    is($model->getType({ name => "eth1", network => "192.168.2.0" }), $expected, "getType: pf.conf type=$pfconf->{type}, enforcement=$pfconf->{enforcement}");
}

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

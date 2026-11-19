#!/usr/bin/perl

=head1 NAME

nas_filter_rule_reply

=head1 DESCRIPTION

The NAS-Filter-Rule attributes of an Access-Accept carry the rules in the
syntax of the switch: without the direction prefix ("in|") that acl_chewer
puts in front of each rule for the module, and without a trailing space when
the rule has no destination port

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::Switch;

my $acl = "permit udp any any\npermit tcp any any eq 80";
my @expected = ("permit in udp from any to any", "permit in tcp from any to any 80");

# module => the attribute its rules are sent in
my @switches = (
    [ 'pf::Switch::Aruba::2930M',               'Aruba-NAS-Filter-Rule' ],
    [ 'pf::Switch::Aruba::ArubaOS_Switch_16_x', 'Aruba-NAS-Filter-Rule' ],
    [ 'pf::Switch::Aruba::5400',                'Aruba-NAS-Filter-Rule' ],
    [ 'pf::Switch::Aruba::ArubaOS_CX_10_x',     'Aruba-NAS-Filter-Rule' ],
    [ 'pf::Switch::HP::AOS_Switch_v16_X',       'HP-NAS-Filter-Rule' ],
);

use Test::More;
plan tests => scalar(@switches) + 2 + 1;
use Test::NoWarnings;

# The access list of the role, translated by the module, without the roles
# configuration or the switch_observability_acls table
{
    no warnings qw(redefine once);
    *pf::Switch::accessListForRequest = sub {
        my ($self) = @_;
        return ('role', $self->acl_chewer($acl, 'testrole'));
    };
    *pf::Switch::getAccessListByName = sub {
        my ($self) = @_;
        my (undef, $acls) = $self->accessListForRequest;
        return $acls;
    };
}

sub new_switch {
    my ($class) = @_;
    eval "require $class; 1" or die $@;
    return $class->new({
        id => '10.9.9.9', ip => '10.9.9.9',
        SNMPUseConnector => 'N', radiusDeauthUseConnector => 'N',
        AccessListMap => 'Y',
    });
}

sub reply_rules {
    my ($switch, $attribute) = @_;
    my ($status, %reply) = @{ $switch->returnRadiusAccessAccept({
        mac => '02:91:35:00:00:01',
        user_role => 'testrole',
        vlan => 1,
        connection_type => 4096,
        radius_request => {},
        node_info => {},
        switch => $switch,
    }) };
    return $reply{$attribute} // [];
}

for my $switch (@switches) {
    my ($class, $attribute) = @$switch;
    is_deeply(reply_rules(new_switch($class), $attribute), \@expected, "$class sends the rules as is in $attribute");
}

my $arista = new_switch('pf::Switch::Arista::AristaSwitch');
is(
    $arista->acl_chewer("permit udp any any", 'testrole'),
    "in|permit in 17 from any to any\n",
    "Arista: no trailing space after a rule without a destination port"
);
is(
    $arista->acl_chewer("permit tcp any any eq 80", 'testrole'),
    "in|permit in 6 from any to any 80\n",
    "Arista: the destination port follows the destination"
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

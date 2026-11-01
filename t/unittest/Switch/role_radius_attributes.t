#!/usr/bin/perl

=head1 NAME

role_radius_attributes

=head1 DESCRIPTION

The RADIUS attributes of the role (Role by RADIUS attributes) are added to the
Access-Accept of the switches

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 11;
use Test::NoWarnings;
use Test::MockModule;
use File::Temp;
use Utils;
use pf::Switch;
use pf::radius;
use pfconfig::manager;
use pfconfig::namespaces::config::Switch;

{
    my $file = File::Temp->new(SUFFIX => '.conf');
    print $file <<'CONF';
[default]
[group radius_attributes]
RadiusAttributesMap=Y
guestRadiusAttributes=Session-Timeout = 30
staffRadiusAttributes=<<EOT
Egress-VLANID = 822083614
Egress-VLANID = 822083624
  Cisco-AVPair  =  shell:priv-lvl=15  
EOT
gamingRadiusAttributes=<<EOT
Session-Timeout = 3600
no equal sign
EOT
[10.0.0.10]
group=radius_attributes
[10.0.0.11]
group=radius_attributes
guestRadiusAttributes=Session-Timeout = 60
CONF
    close $file;
    my $namespace = pfconfig::namespaces::config::Switch->new(pfconfig::manager->new);
    $namespace->{file} = $file->filename;
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $switches = $namespace->build;
    is_deeply($switches->{'10.0.0.10'}{radius_attributes},
        {
            guest => [ 'Session-Timeout', 30 ],
            staff => [ 'Egress-VLANID', 822083614, 'Egress-VLANID', 822083624, 'Cisco-AVPair', 'shell:priv-lvl=15' ],
        },
        'the lines are split at the first equal sign, inherited from the group, and a role with an invalid line gets no attributes');
    is_deeply([ map { /(\[.+ is not a valid radius attribute)/ ? $1 : $_ } @warnings ],
        [ "[group radius_attributes] gamingRadiusAttributes: 'no equal sign' is not a valid radius attribute" ],
        'an invalid line is logged once, for the section that sets it');
    is_deeply($switches->{'10.0.0.11'}{radius_attributes}{guest}, [ 'Session-Timeout', 60 ],
        'the RADIUS attributes of the role of the switch replace the ones of its group');
}

{
    my $switch = pf::Switch->new({ id => '10.0.0.8', radius_attributes => { staff => [ 'Session-Timeout', 3600 ] } });
    is_deeply([ $switch->getRadiusAttributesByName('staff') ], [ 'Session-Timeout', 3600 ], 'the attributes of the role are returned');
    is_deeply([ $switch->getRadiusAttributesByName('guest') ], [], 'nothing is returned for another role');
}

is_deeply(
    [ pf::radius::_merge_radius_attrs('Session-Timeout' => 60, 'Session-Timeout' => 3600, 'Egress-VLANID' => 822083614, 'Egress-VLANID' => 822083624) ],
    [ 'Session-Timeout' => [ 60, 3600 ], 'Egress-VLANID' => [ 822083614, 822083624 ] ],
    'the attributes are added to the ones of the reply'
);

sub authorize {
    my ($switch_id) = @_;
    my $mac = Utils::test_mac();
    my ($status, %reply) = @{ pf::radius->new->authorize({
        'User-Name'          => $mac,
        'User-Password'      => $mac,
        'NAS-IP-Address'     => $switch_id,
        'NAS-Port'           => 1,
        'NAS-Port-Type'      => 15,
        'Service-Type'       => 10,
        'Called-Station-Id'  => '00:1a:1e:01:68:f8',
        'Calling-Station-Id' => $mac,
    }) };
    return \%reply;
}

{
    my $reply = authorize('172.16.8.45');
    is($reply->{'Filter-Id'}, 'role-radius-attributes', 'the RADIUS attributes of the role are in the Access-Accept');
    is_deeply($reply->{'Egress-VLANID'}, [ 822083614, 822083624 ], 'an attribute set several times is returned several times');
    ok(!exists authorize('172.16.8.46')->{'Filter-Id'}, 'nothing is added when Role by RADIUS attributes is disabled');
}

{
    # A reject, as for the REJECT role or a RADIUS filter that sets radius_status
    my $mock = Test::MockModule->new('pf::Switch::Template');
    $mock->mock(returnRadiusAccessAccept => sub { [ $RADIUS::RLM_MODULE_USERLOCK ] });
    ok(!exists authorize('172.16.8.45')->{'Filter-Id'}, 'nothing is added to a reject');
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

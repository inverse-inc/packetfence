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

use Test::More tests => 8;
use Test::NoWarnings;
use File::Temp;
use pf::Switch;
use pf::radius;
use pfconfig::manager;
use pfconfig::namespaces::config::Switch;

my $attributes = <<'EOT';
# VLANs 30 and 40 tagged (RFC 4675: 0x31000000 + VLAN)
Egress-VLANID = 822083614
Egress-VLANID = 822083624

Session-Timeout=3600
EOT

sub attributes {
    my ($role, $switch_args) = @_;
    return pf::Switch->new({
        id => '10.0.0.8',
        RadiusAttributesMap => 'Y',
        radius_attributes => { staff => $attributes },
        %{$switch_args // {}},
    })->getRadiusAttributesByName($role);
}

is_deeply(
    [ attributes('staff') ],
    [ 'Egress-VLANID', 822083614, 'Egress-VLANID', 822083624, 'Session-Timeout', 3600 ],
    'the attributes of the role are returned, without the comments and the empty lines'
);
is_deeply(
    [ attributes('staff', { radius_attributes => { staff => [ split /\n/, $attributes ] } }) ],
    [ attributes('staff') ],
    'Config::IniFiles returns a multi-line value as an array'
);
is_deeply(
    [ attributes('staff', { radius_attributes => { staff => "Altiga-Simultaneous-Logins-G/U = 5\n  Cisco-AVPair  =  shell:priv-lvl=15  \nno equal sign\n= no name" } }) ],
    [ 'Altiga-Simultaneous-Logins-G/U', 5, 'Cisco-AVPair', 'shell:priv-lvl=15' ],
    'a line is split at the first equal sign, as in the switch templates'
);
is_deeply([ attributes('guest') ], [], 'nothing is returned for another role');
is_deeply([ attributes('staff', { RadiusAttributesMap => 'N' }) ], [], 'nothing is returned when Role by RADIUS attributes is disabled');

is_deeply(
    [ pf::radius::_merge_radius_attrs('Session-Timeout' => 60, attributes('staff')) ],
    [ 'Session-Timeout' => [ 60, 3600 ], 'Egress-VLANID' => [ 822083614, 822083624 ] ],
    'the attributes are added to the ones of the reply'
);

{
    my $file = File::Temp->new(SUFFIX => '.conf');
    print $file <<'CONF';
[default]
[group radius_attributes]
RadiusAttributesMap=Y
guestRadiusAttributes=Session-Timeout = 30
staffRadiusAttributes=Session-Timeout = 60
[10.0.0.10]
group=radius_attributes
CONF
    close $file;
    my $namespace = pfconfig::namespaces::config::Switch->new(pfconfig::manager->new);
    $namespace->{file} = $file->filename;
    my $switches = $namespace->build;
    is_deeply($switches->{'10.0.0.10'}{radius_attributes},
        { guest => 'Session-Timeout = 30', staff => 'Session-Timeout = 60' },
        'a switch inherits the RADIUS attributes of the roles of its group');
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

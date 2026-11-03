#!/usr/bin/perl

=head1 NAME

port_bounce_coa

=head1 DESCRIPTION

The ArubaOS-Switch modules identify the port with NAS-Port in the port bounce
CoA (HP-Port-Bounce-Host): the switch rejects a NAS-Port-Id with a CoA-NAK
(#6371). The role CoA (Filter-Id) keeps NAS-Port-Id.

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

my @MODULES = qw(
    pf::Switch::HP::AOS_Switch_v16_X
    pf::Switch::Aruba::2930M
    pf::Switch::Aruba::ArubaOS_Switch_16_x
    pf::Switch::Aruba::5400
);

use Test::More tests => 4 * 6 + 1;

#This test will running last
use Test::NoWarnings;
use pf::roles::custom;

for my $module (@MODULES) {
    eval "require $module" or die $@;
}

# Send a CoA through radiusDisconnect with the network calls stubbed out and
# return the attributes and VSAs given to handleRadiusCoa
sub coa_for {
    my ($module, $use_coa) = @_;
    my ($attributes, $vsa);
    no strict 'refs';
    no warnings qw(redefine once);
    # radiusDisconnect is either the module's own or the one of AOS_Switch_v16_X,
    # which imports locationlog_view_open_mac into its package
    local *{"${module}::locationlog_view_open_mac"} = sub { return { port => 12, dot1x_username => 'user' } };
    local *pf::Switch::HP::AOS_Switch_v16_X::locationlog_view_open_mac = sub { return { port => 12, dot1x_username => 'user' } };
    # and the one of pf::Switch, used by locationlog_for_disconnect (#9490)
    local *pf::Switch::locationlog_view_open_mac = sub { return { port => 12, dot1x_username => 'user' } };
    local *pf::roles::custom::getRoleForNode = sub { return 'guest' };
    local *pf::Switch::radius_deauth_connection_info = sub { return {} };
    local *pf::Switch::shouldUseCoA = sub { return $use_coa };
    local *pf::Switch::handleRadiusCoa = sub {
        my ($self, $connection_info, $attributes_ref, $vsa_ref) = @_;
        ($attributes, $vsa) = ($attributes_ref, $vsa_ref);
        return { Code => 'CoA-ACK' };
    };
    my $switch = $module->new({ id => '192.168.1.1', ip => '192.168.1.1', radiusSecret => 'secret' });
    $switch->radiusDisconnect('00:11:22:33:44:55');
    return ($attributes, $vsa);
}

for my $module (@MODULES) {
    my ($attributes, $vsa) = coa_for($module, 0);
    is_deeply([ map { $_->{attribute} } @{ $vsa // [] } ], ['HP-Port-Bounce-Host'], "$module: port bounce CoA sends HP-Port-Bounce-Host");
    is($attributes->{'NAS-Port'}, 12, "$module: port bounce CoA identifies the port with NAS-Port");
    ok(!exists $attributes->{'NAS-Port-Id'}, "$module: port bounce CoA has no NAS-Port-Id");

    ($attributes, $vsa) = coa_for($module, 1);
    is($attributes->{'Filter-Id'}, 'guest', "$module: role CoA sends the role in Filter-Id");
    is($attributes->{'NAS-Port-Id'}, 12, "$module: role CoA keeps NAS-Port-Id");
    ok(!exists $attributes->{'NAS-Port'}, "$module: role CoA has no NAS-Port");
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

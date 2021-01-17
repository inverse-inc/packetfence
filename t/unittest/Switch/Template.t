#!/usr/bin/perl

=head1 NAME

Template

=head1 DESCRIPTION

unit test for Template

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';
use pf::util::template_switch;
use pf::config::builder::template_switches;
use pf::Switch::Template;
our @FILES;
our $SWITCH_DIR;
BEGIN {
    $SWITCH_DIR = '/usr/local/pf/lib/pf/Switch';
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    @FILES = pf::util::template_switch::getDefFiles($SWITCH_DIR);
}

my $builder = pf::config::builder::template_switches->new;
use Test::More tests => (scalar @FILES) + 15;
#This test will running last
use Test::NoWarnings;
use pf::util::template_switch;

{
    my $class = 'pf::Switch::PacketFence::Test';
    pf::util::template_switch::createFakeTemplateModule($class);
    my $template = $class->_template();
    is(ref($template), 'HASH', "Getting the hash data from just the class $class");
}

{
    my $switch = pf::SwitchFactory->instantiate('172.16.8.28');
    ok($switch->supportsExternalPortal(), "supportsExternalPortal");
    ok($switch->canDoAcceptUrl(), "canDoAcceptUrl");
    my $radius_reply = {};
    $switch->addAcceptUrlAttributes($radius_reply, {mac => "aa:bb:cc:dd:ee:ff"});
    is_deeply($radius_reply, {}, "addAcceptUrlAttributes added nothing");

    $switch->addAcceptUrlAttributes($radius_reply, {mac => "aa:bb:cc:dd:ee:ff", user_role => "bob"});
    ok(exists $radius_reply->{'Cisco-AVPair'}, "addAcceptUrlAttributes added Cisco-AVPair");
    is(scalar @{$radius_reply->{'Cisco-AVPair'} // []}, 2, "addAcceptUrlAttributes added multiple Cisco-AVPair" );
    my $url= $radius_reply->{'Cisco-AVPair'}[1];
    ok($url =~ /^url-redirect=/);
    ok($url =~ m#http://10.0.60.149/PacketFence::Test/#);
}

for my $file (@FILES) {
    my $name = pf::util::template_switch::fileNameToModuleName($SWITCH_DIR, $file);
    my $ini = pf::IniFiles->new( -file => $file, -fallback => $name);
    if (!defined $ini) {
        fail("load $file");
        next;
    }

    my ($error, undef) = $builder->build($ini);
    ok(!defined $error, "Building $file ");
}

{

    local $pf::Switch::Template::LOOKUP{last_accounting} = sub { { a => 1, b => 2 } };
    my %args = ();
    my $set  = [
        {
            name => 'Reply-Message',
            tmpl => pf::mini_template->new('$last_accounting')
        },
    ];
    pf::Switch::Template->updateArgsVariablesForSet( \%args, $set );
    is_deeply(\%args, { last_accounting => { a => 1, b => 2 }}, "updateArgsVariablesForSet filled in empty args");
    %args = ( last_accounting => { c => 3, d => 4} );
    pf::Switch::Template->updateArgsVariablesForSet( \%args, $set );
    is_deeply(\%args, { last_accounting => { c => 3, d => 4 }}, "updateArgsVariablesForSet ignored existing args");
}

{
    my $switch = pf::SwitchFactory->instantiate('172.16.8.27');
    ok($switch->supportsExternalPortal(), "supportsExternalPortal");
}

{
    my $switch = pf::SwitchFactory->instantiate('172.16.8.26');
    is (
        $switch->NasPortToIfIndex("500101"),
        "101101",
        "NasPortToIfIndex"
    );
}

{
    my $switch = pf::SwitchFactory->instantiate('172.16.8.27');
    is_deeply(
        $switch->returnAuthorizeRead({user_name => 'bob', switch => $switch }),
        [$RADIUS::RLM_MODULE_OK, 'Cisco-AVPair' => 'shell:priv-lvl=3'],
        "returnAuthorizeRead"
    );
    is_deeply(
        $switch->returnAuthorizeWrite({user_name => 'bob', switch => $switch }),
        [$RADIUS::RLM_MODULE_OK, 'Cisco-AVPair' => 'shell:priv-lvl=15'],
        "returnAuthorizeWrite"
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

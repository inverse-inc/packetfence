#!/usr/bin/perl

=head1 NAME

Template

=head1 DESCRIPTION

unit test for Template

=cut

use strict;
use warnings;
#
our @FILES;
our $SWITCH_DIR;
BEGIN {
    $SWITCH_DIR = '/usr/local/pf/lib/pf/Switch';
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    use pf::util::template_switch;
    @FILES = pf::util::template_switch::getDefFiles($SWITCH_DIR);
}

use pf::config::builder::template_switches;
use pf::Switch::Template;
my $builder = pf::config::builder::template_switches->new;
use Test::More tests => (scalar @FILES) + 6;
#This test will running last
use Test::NoWarnings;
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
    my $switch = pf::SwitchFactory->instantiate('172.16.8.25');
    my ($switchdeauthMethod, $deauthTechniques) = $switch->deauthTechniques($switch->{'_deauthMethod'});
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

Copyright (C) 2005-2024 Inverse inc.

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

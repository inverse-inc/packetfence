#!/usr/bin/perl

=head1 NAME

wmi_action

=head1 DESCRIPTION

unit test for wmi_action

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 10;

#This test will running last
use Test::NoWarnings;
use pf::config::builder::wmi_action;
use pf::IniFiles;

my $builder = pf::config::builder::wmi_action->new;

{

    my $conf = <<'CONF';
[Google]
attribute = Caption
operator = match
value = Google

[Infiles]
attribute = Caption
operator = advance
value = FUNC(

[1:Google]
action=trigger_violation
action_param = mac = $mac, tid = 888888, type = INTERNAL
CONF

    my ($error, $filters) = build_from_conf($conf);
    is(scalar @$error, 1, "Error found");
    is(scalar @$filters, 1, "1 filter built");
}


{

    my $conf = <<'CONF';
[Google]
attribute = Caption
operator = match
value = Google

[Infiles]
attribute = Caption
operator = advance
value = Date.Now()

[1:Google]
action=trigger_violation
action_param = mac = $mac, tid = 888888, type = INTERNAL

[2:Infiles]
action=trigger_violation
action_param = mac = $mac, tid = 888888, type = INTERNAL
CONF

    my ($error, $filters) = build_from_conf($conf);
    is($error, undef, "No Error found");
    is(scalar @$filters, 2, "2 filters built");
    is_deeply(
        $filters->[0],
          bless( {
                   'answer' => {
                                 'action_param' => 'mac = $mac, tid = 888888, type = INTERNAL',
                                 '_rule' => '1:Google',
                                 'action' => 'trigger_violation'
                               },
                   'condition' => bless( {
                                           'match_on_empty' => 0,
                                           'condition' => bless( {
                                                                   'condition' => bless( {
                                                                                           'value' => 'Google'
                                                                                                                 }, 'pf::condition::matches' ),
                                                                   'key' => 'Caption'
                                                                 }, 'pf::condition::key' )
                                         }, 'pf::condition::multi_any' )
                 }, 'pf::filter' ),
    );
}

{
    my $conf = <<'CONF';
[Google]
operator = true

[1:Google]
only_match_when_empty=enabled
action=trigger_violation
action_param = mac = $mac, tid = 888888, type = INTERNAL
CONF

    my ($error, $filters) = build_from_conf($conf);
    is($error, undef, "No Error found");
    is(scalar @$filters, 1, "1 filter built");
    is_deeply(
        $filters->[0],
          bless( {
                   'answer' => {
                                 'only_match_when_empty' => 'enabled',
                                 'action_param' => 'mac = $mac, tid = 888888, type = INTERNAL',
                                 '_rule' => '1:Google',
                                 'action' => 'trigger_violation'
                               },
                   'condition' => bless( {
                                           'condition' => bless( { }, 'pf::condition::true' )
                                         }, 'pf::condition::multi_empty' )
                 }, 'pf::filter' ),
        "Filter Building",
    );

    isa_ok($filters->[0]{condition}, 'pf::condition::multi_empty');
}

sub build_from_conf {
    my ($conf) = @_;
    my $ini = pf::IniFiles->new(-file => \$conf);
    return $builder->build($ini);
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

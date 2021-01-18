#!/usr/bin/perl

=head1 NAME

Switch

=head1 DESCRIPTION

unit test for Switch

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
use Utils;
use pf::ConfigStore::Switch;
my ($fh, $filename) = Utils::tempfileForConfigStore("pf::ConfigStore::Switch");

#This test will running last
use Test::NoWarnings;
my $old;
my $new;
{
    my $cs = pf::ConfigStore::Switch->new;
    $old = $cs->read('111.1.1.1');
    $cs->update('111.1.1.1', { voiceVlan => 501 });
    $cs->commit;
}
my $oldVoiceVlan = $old->{voiceVlan};

{
    my $cs = pf::ConfigStore::Switch->new;
    $cs->update('111.1.1.1', { voiceVlan => undef });
    $cs->commit;
}

{
    my $cs = pf::ConfigStore::Switch->new;
    $new = $cs->read('111.1.1.1');
}

is($new->{voiceVlan}, $oldVoiceVlan, "delete inherited values");
{
    my $cs = pf::ConfigStore::Switch->new;
    is_deeply(
        [$cs->parentSections('id', {group => 'bob'})],
        ['group bob', 'default'],
        "",
    );

    is_deeply(
        [$cs->parentSections('default', {group => 'bob'})],
        [],
        "parentSections of default section"
    );

    is_deeply(
        [$cs->parentSections('default' )],
        [],
    );

    is_deeply(
        [$cs->parentSections('bob', {group => 'bob'})],
        ['default'],
    );

    is_deeply(
        [$cs->parentSections('111.1.1.1', {})],
        ['group bug-5482', 'default'],
        "parentSections for bug-5482"
    );

    is_deeply(
        [$cs->parentSections('111.1.1.1', { group => 'bob'})],
        ['group bob', 'default'],
        "parentSections for bug-5482 with defined group"
    );

    is_deeply(
        [$cs->parentSections('bug-5482', { })],
        ['default'],
        "parentSections for bug-5482"
    );

}

{
    my $cs = pf::ConfigStore::Switch->new;
    $cs->update('172.16.8.21', { registrationVlan => 3 });
    $cs->commit;
}

{
    my $cs = pf::ConfigStore::Switch->new;
    my $data = $cs->read('172.16.8.21');
    is($data->{registrationVlan}, 3);
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


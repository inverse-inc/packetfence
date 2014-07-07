#!/usr/bin/perl
=head1 NAME

autoconfig add documentation

=cut

=head1 DESCRIPTION

config-cached

=cut

use strict;
use warnings;
# pf core libs
use lib '/usr/local/pf/lib';

BEGIN {
    use lib qw(/usr/local/pf/t);
    use PfFilePaths;
}
use Test::More tests => 9;

use Test::NoWarnings;
use Test::Exception;

our $TEST_CATEGORY = "test";

our $TEST_OS = 'Apple iPod, iPhone or iPad',

our $TEST_NODE_ATTRIBUTE = { category => $TEST_CATEGORY };

use_ok("pf::provisioner::autoconfig");

my $provisioner = new_ok(
    "pf::provisioner::autoconfig",
    [{
        type     => 'autoconfig',
        category => $TEST_CATEGORY,
        template => 'dummy',
        oses     => [$TEST_OS],
    }]
);

ok($provisioner->match($TEST_OS,$TEST_NODE_ATTRIBUTE),"Match both os and category");

ok(!$provisioner->match('Android',$TEST_NODE_ATTRIBUTE),"Don't Match os but Matching category");

ok(!$provisioner->match('Android','not_matching'),"Don't Match os and category");

$provisioner->category('not_matching');

ok(!$provisioner->match($TEST_OS,$TEST_NODE_ATTRIBUTE),"Match os but not category");

$provisioner->category('any');

ok($provisioner->match($TEST_OS,$TEST_NODE_ATTRIBUTE),"Match os with the any category");

ok(!$provisioner->match('Android',$TEST_NODE_ATTRIBUTE),"Don't match os with the any category");


1;



#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

BEGIN { push @ARGV, "--dbitest"; }

use Test::MockDBI qw( :all );
use Test::More tests => 3;
use lib '/usr/local/pf/lib';
BEGIN { use_ok('pf::person') }

my $md = Test::MockDBI::get_instance();
$pf::db::dbh = DBI->connect( "", "", "" );

# Set of return values for given sql query
$md->set_retval_scalar(
    MOCKDBI_WILDCARD,
    "select pid,notes from person where pid=?",
    { pid => '1', notes => 'toto' }
);
is_deeply( person_view(1), { pid => '1', notes => 'toto' }, 'person_view' );

my $returnRef = [
    { pid => '1', notes => 'toto' },
    { pid => '2', notes => 'second' }
];
my $returnRefBackup = [
    { pid => '1', notes => 'toto' },
    { pid => '2', notes => 'second' }
];
$md->set_retval_scalar(
    MOCKDBI_WILDCARD,
    "select pid,notes from person",
    sub { shift @$returnRef }
);
my @person_view_return = person_view_all();
is_deeply( \@person_view_return, $returnRefBackup, 'person_view_all' );

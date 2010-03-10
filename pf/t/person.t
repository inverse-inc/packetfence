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
$pf::db::dbh{0} = DBI->connect( "", "", "" );

# TODO this used to work in the days where person_view(1) and person_view_all re-did their statement handlers in their
# context (check mtn log). Probably some Test::MockDBI magic causing a problem.
# this in the person_view sub worked:
# my $query = get_db_handle()->prepare("select pid,firstname,lastname,email,telephone,company,address,notes from person where pid=?");
# then my $ref = $query->fetchrow_...
# also note that in pf::db::db_query_handler DBI::st will need to change in ref($db_statement) eq 'DBI::st') 
# because ref() on the MockDBI returns DBI instead of DBI::st

# Set of return values for given sql query
$md->set_retval_scalar(
    MOCKDBI_WILDCARD,
    "select pid,firstname,lastname,email,telephone,company,address,notes from person where pid=?",
    { 
        pid       => '1', 
        firstname => 'first',
        lastname  => 'last',
        email     => 'email',
        telephone => 'telephone',
        company   => 'company',
        address   => 'address',
        notes     => 'notes' 
    }
);
is_deeply( 
    person_view(1), 
    { 
        pid => '1', 
        firstname => 'first',
        lastname  => 'last',
        email     => 'email',
        telephone => 'telephone',
        company   => 'company',
        address   => 'address',
        notes     => 'notes' 
    },
    'person_view' 
);

my $returnRef = [
    { 
        pid       => '1',
        firstname => 'first1',
        lastname  => 'last1',
        email     => 'email1',
        telephone => 'telephone1',
        company   => 'company1',
        address   => 'address1',
        notes     => 'notes1' 
    },
    { 
        pid       => '2',
        firstname => 'first2',
        lastname  => 'last2',
        email     => 'email2',
        telephone => 'telephone2',
        company   => 'company2',
        address   => 'address2',
        notes     => 'notes2' 
    }
];
my $returnRefBackup = [
    { 
        pid       => '1',
        firstname => 'first1',
        lastname  => 'last1',
        email     => 'email1',
        telephone => 'telephone1',
        company   => 'company1',
        address   => 'address1',
        notes     => 'notes1'
    },
    {
        pid       => '2',
        firstname => 'first2',
        lastname  => 'last2',
        email     => 'email2',
        telephone => 'telephone2',
        company   => 'company2',
        address   => 'address2',
        notes     => 'notes2'
    }
];
$md->set_retval_scalar(
    MOCKDBI_WILDCARD,
    "select pid,firstname,lastname,email,telephone,company,address,notes from person",
    sub { shift @$returnRef }
);
my @person_view_return = person_view_all();
is_deeply( \@person_view_return, $returnRefBackup, 'person_view_all' );

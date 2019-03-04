#!/usr/bin/perl -w

=head1 NAME

dao/person.t

=head1 DESCRIPTION

Tests on pf::person that will have impact on the database.

=cut

require 5.8.8;
use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::NoWarnings;
use Test::More tests => 14;

use Log::Log4perl;
use Readonly;

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( "dao/person.t" );
Log::Log4perl::MDC->put( 'proc', "dao/person.t" );
Log::Log4perl::MDC->put( 'tid',  0 );

use pf::constants;
use pf::config;
use lib qw(/usr/local/pf/t);
use TestUtils;
BEGIN { use_ok('pf::person') }

# override database connection settings to connect to test database
TestUtils::use_test_db();

# Example data
# here I am keeping the PID seperate to simplify person_modify tests
Readonly my $PERSON1_PID => 'aeinstein';
Readonly my %PERSON1 => (
    'firstname' => 'Albert',
    'lastname' => 'Einstein',
    'email' => 'albert.einstein@einstein.yu.edu',
    'telephone' => '514-555-3467',
    'company' => 'Physics',
    'address' => '500 West 185th Street, New York',
    'notes' => 'Treat this man with respect',
    'sponsor' => '',
);
Readonly my $PERSON2_PID => 'inewton';
Readonly my %PERSON2 => (
    'firstname' => 'Isaac',
    'lastname' => 'Newton',
    'email' => 'isaac.newton@cam.ac.uk',
    'telephone' => '514-555-6398',
    'company' => 'Physics',
    'address' => 'The Old Schools, Trinity Lane, Cambridge CB2 1TN, UK',
    'notes' => 'Not very good with computers',
    'sponsor' => '',
);
Readonly my %DEFAULT_PERSON => (
    'pid' => '1',
    'firstname' => undef,
    'lastname' => undef,
    'email' => undef,
    'telephone' => undef,
    'company' => undef,
    'address' => undef,
    'notes' => 'Default User - do not delete',
    'sponsor' => undef,
);
Readonly my $UNKNOWN_PERSON => "mtheresa";

# person_add
is(
    person_add( $PERSON1_PID, %PERSON1 ),
    $TRUE,
    "person_add successful"
);

# TODO constantify error return value in pf::person
is(
    person_add( $PERSON1_PID, %PERSON1 ),
    2,
    "person_add but already exists expect return 2"
);


# person_exist
is(
    person_exist( $PERSON1_PID ),
    $TRUE,
    "person_exist on existing person"
);

is(
    person_exist( $UNKNOWN_PERSON ),
    $FALSE,
    "person_exist on unknown person expect false"
);


# person_view
is_deeply(
    person_view( $PERSON1_PID ),
    # turning into an hash reference and adding person pid to the result because it'll be in the record
    { %PERSON1, 'pid' => $PERSON1_PID },
    "person_view on existing person"
);

is(
    person_view( $UNKNOWN_PERSON ),
    undef,
    "person_view on unknown person expect undef"
);

# person_view_all
my @persons = person_view_all();
is_deeply(
    \@persons,
    # turning into an array reference and adding person pid to the result because it'll be in the record
    [ \%DEFAULT_PERSON, { %PERSON1, 'pid' => $PERSON1_PID } ],
    "person_view_all default + person1"
);

person_add( $PERSON2_PID, %PERSON2 );
@persons = person_view_all();
is_deeply(
    \@persons,
    # turning into an array reference and adding person pid to the result because it'll be in the record
    [ \%DEFAULT_PERSON, { %PERSON1, 'pid' => $PERSON1_PID }, { %PERSON2, 'pid' => $PERSON2_PID } ],
    "person_view_all default + person1 + person2"
);


# person_modify
# Putting person2's info on person1 to see if person_modify worked
is(
    person_modify( $PERSON1_PID, %PERSON2 ),
    $TRUE,
    "person_modify returned true"
);

is_deeply(
    person_view( $PERSON1_PID ),
    # turning into an hash reference and adding person pid to the result because it'll be in the record
    { 'pid' => $PERSON1_PID, %PERSON2 },
    "person_modify worked"
);


# person_delete
is(
    person_delete( $PERSON1_PID ),
    $TRUE,
    "person_delete successful"
);
person_delete( $PERSON2_PID ),

is(
    person_delete( $UNKNOWN_PERSON ),
    $FALSE,
    "person_delete on unknown person expect false"
);
# TODO try to delete a person with nodes registered

# TODO test person_nodes()

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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


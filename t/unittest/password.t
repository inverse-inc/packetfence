#!/usr/bin/perl

use strict;
use warnings;

#use Test::More 'no_plan';
use Test::More tests => 11;
my $FALSE = 0;
my $TRUE = 1;

BEGIN {
    use setup_test_config;
    use_ok('pf::password') or die;
    use pf::password;
}
can_ok('pf::password', qw(  bcrypt ) ) or die;

like( pf::password::bcrypt( "helloworld"), qr/^\{bcrypt\}\$2[ay]\$\d\d\$/, "bcrypt hash has the correct prefix");
is( length pf::password::bcrypt( "helloworld"), (length('{bcrypt}') + 60), "bcrypt hash has the right length");

is( pf::password::bcrypt( "helloworld", cost => 8, salt => "X6vbzGba/PiJ9JTbexP.5u" ),
    q[{bcrypt}$2a$08$X6vbzGba/PiJ9JTbexP.5uZRmDcYo0twoqBNyUjvcyfPV/kWprcYy],
    "bcrypt returns the right hash given a set input" );



is( pf::password::_check_password(
        "helloworld",
        q[{bcrypt}$2a$08$X6vbzGba/PiJ9JTbexP.5uZRmDcYo0twoqBNyUjvcyfPV/kWprcYy],
    ),
    $TRUE,
    "_check_password returns \$TRUE with known bcrypt input"
);


is( pf::password::_check_password(
        "helloworld",
        'helloworld',
        ),
    $TRUE,
    "_check_password returns \$TRUE with known plaintext input"
);

is( pf::password::_check_password(
        "somethingelse",
        q[{bcrypt}$2a$08$X6vbzGba/PiJ9JTbexP.5uZRmDcYo0twoqBNyUjvcyfPV/kWprcYy],
        ),
    $FALSE,
    "_check_password returns \$FALSE with known bcrypt input"
);

is( pf::password::_check_password(
        "somethingelse",
        q{helloworld},
        ),
    $FALSE,
    "_check_password returns \$FALSE with known plaintext input"
);

is(pf::password::password_get_hash_type("jhsjdhsahd"), 'plaintext', "Password type is plaintext");

is(pf::password::password_get_hash_type(q[{bcrypt}$2a$08$X6vbzGba/PiJ9JTbexP.5uZRmDcYo0twoqBNyUjvcyfPV/kWprcYy]),
    'bcrypt', "Password type is bcrypt");

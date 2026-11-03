#!/usr/bin/perl

use strict;
use warnings;

#use Test::More 'no_plan';
my $FALSE = 0;
my $TRUE = 1;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 20;
use pf::person;
use pf::dal::password;
use Utils;
use_ok('pf::password') or die;
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

my $test_pid = Utils::test_pid();
pf::person::person_add($test_pid);
my $new_password = pf::password::generate( $test_pid, []);
is(
   pf::password::validate_password($test_pid, $new_password),
   $pf::password::AUTH_SUCCESS,
   "Password without potd"
);

is(
   pf::password::validate_password($test_pid, $new_password, 1),
   $pf::password::AUTH_FAILED_INVALID,
   "password with potd failed"
);

person_modify($test_pid, potd => 'yes');

is(
   pf::password::validate_password($test_pid, $new_password),
   $pf::password::AUTH_FAILED_INVALID,
   "Password without potd succeeded",
);

is(
   pf::password::validate_password($test_pid, $new_password, 1),
   $pf::password::AUTH_SUCCESS,
   "password with potd succeeded",
);

# The validity window of a password, also after 2038 (#9122)
my $window_pid = Utils::test_pid();
pf::person::person_add($window_pid);
my $window_password = pf::password::generate($window_pid, []);
sub set_window {
    my ($valid_from, $expiration) = @_;
    pf::dal::password->update_items(
        -set => { valid_from => $valid_from, expiration => $expiration },
        -where => { pid => $window_pid },
    );
}

set_window('2026-01-01 00:00:00', '2040-01-01 00:00:00');
is(pf::password::validate_password($window_pid, $window_password), $pf::password::AUTH_SUCCESS, "expiration after 2038");

set_window('2026-01-01 00:00:00', '2026-01-02 00:00:00');
is(pf::password::validate_password($window_pid, $window_password), $pf::password::AUTH_FAILED_EXPIRED, "expired password");

set_window('2039-01-01 00:00:00', '2040-01-01 00:00:00');
is(pf::password::validate_password($window_pid, $window_password), $pf::password::AUTH_FAILED_NOT_YET_VALID, "valid from after 2038");

set_window('0000-00-00 00:00:00', '2040-01-01 00:00:00');
is(pf::password::validate_password($window_pid, $window_password), $pf::password::AUTH_SUCCESS, "no valid from");

set_window('2026-01-01 00:00:00', '0000-00-00 00:00:00');
is(pf::password::validate_password($window_pid, $window_password), $pf::password::AUTH_FAILED_EXPIRED, "no expiration is expired, as before");

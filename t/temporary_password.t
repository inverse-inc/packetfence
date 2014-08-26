use strict;
use warnings;

#use Test::More 'no_plan';
use Test::More tests => 9;
my $FALSE = 0;
my $TRUE = 1;  

BEGIN { 
    use_ok('pf::temporary_password') or die;
    use pf::temporary_password 'bcrypt'; 
} 
can_ok('pf::temporary_password', qw(  bcrypt ) ) or die;

like( bcrypt( "helloworld"), qr/^\$2[ay]\$\d\d\$/, "bcrypt hash has the correct prefix");
is( length bcrypt( "helloworld"), 60, "bcrypt hash has the right length");

is( bcrypt( "helloworld", cost => 8, salt => "X6vbzGba/PiJ9JTbexP.5u" ),
    q{$2a$08$X6vbzGba/PiJ9JTbexP.5uZRmDcYo0twoqBNyUjvcyfPV/kWprcYy},
    "bcrypt returns the right hash given a set input" );

is( pf::temporary_password::_check_password( 
        "helloworld",
        q{$2a$08$X6vbzGba/PiJ9JTbexP.5uZRmDcYo0twoqBNyUjvcyfPV/kWprcYy}, 
        'bcrypt' ),
    $TRUE,
    "_check_password returns \$TRUE with known bcrypt input"
);


is( pf::temporary_password::_check_password( 
        "helloworld",
        q{helloworld}, 
        'plaintext' ),
    $TRUE,
    "_check_password returns \$TRUE with known plaintext input"
);

is( pf::temporary_password::_check_password( 
        "somethingelse",
        q{$2a$08$X6vbzGba/PiJ9JTbexP.5uZRmDcYo0twoqBNyUjvcyfPV/kWprcYy}, 
        'bcrypt' ),
    $FALSE,
    "_check_password returns \$FALSE with known bcrypt input"
);

is( pf::temporary_password::_check_password( 
        "somethingelse",
        q{helloworld}, 
        'plaintext' ),
    $FALSE,
    "_check_password returns \$FALSE with known plaintext input"
);

#!/usr/bin/perl
=head1 NAME

web-auth.t

=head1 DESCRIPTION

pf::web::auth module testing

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use File::Basename qw(basename);
use Log::Log4perl;
use Try::Tiny;

use Test::Exception;
use Test::More tests => 24;
use Test::NoWarnings;

Log::Log4perl->init("log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  0 );

BEGIN { 
    use_ok('pf::web::auth'); 
}

# testing interface of base class
can_ok('pf::web::auth', qw(initialize instantiate list_enabled_auth_types));

my @auth_modules = qw(
    guest_managers
    kerberos
    ldap
    local
    preregistered_guests
    radius
);

foreach my $auth_module (@auth_modules) {
    use_ok("authentication::$auth_module");

    # test the objects
    my $authentication = new {"authentication::$auth_module"}();
    isa_ok($authentication, 'pf::web::auth');

    # subs
    can_ok($authentication, qw(
        authenticate
        getName
        new
    ));
}

# authentication::local
my $local_auth = new authentication::local();
{
    # modify $password_file so that t/data/user.conf will be loaded instead of conf/user.conf
    no warnings 'once';
    $authentication::local::password_file = 'data/user.conf';
}
ok($local_auth->authenticate("user", "testpass"), "working account expecting success");

# ERROR HANDLING

# make sure we catch wrong module name or failing object creation
my $auth = 'invalid';
eval "use authentication::$auth";
ok($@, "non-existent authentication classname");

my $failed_creation;
throws_ok { $failed_creation = new {"authentication::$auth"}(); }
    qr/Can't locate object method "new"/,
    "trapped bad object creation"
;

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


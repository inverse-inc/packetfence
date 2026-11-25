#!/usr/bin/perl

=head1 NAME

KerberosSource

=head1 DESCRIPTION

The Kerberos source authenticates the users in the realm of the source

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 16;
use pf::Authentication::Source::KerberosSource;
use Authen::Krb5::Simple;

#This test will running last
use Test::NoWarnings;

my @principals;
{
    no warnings 'redefine';
    # Record the principals and accept any password
    *Authen::Krb5::Simple::authenticate = sub { my ($self, $user, $password) = @_; push @principals, $user; return 1 };
}

my $source = pf::Authentication::Source::KerberosSource->new({
    id => 'kerberos_test',
    host => 'kdc.example.org',
    authenticate_realm => 'EXAMPLE.ORG',
});

sub authenticated_as {
    my ($username, $password) = @_;
    @principals = ();
    my ($result) = $source->authenticate($username, $password // 'password');
    return $result ? $principals[0] : undef;
}

is(authenticated_as('user'), 'user@EXAMPLE.ORG', 'the realm of the source is added');
is(authenticated_as('user@EXAMPLE.ORG'), 'user@EXAMPLE.ORG', 'the realm of the source is accepted');
is(authenticated_as('user@example.org'), 'user@EXAMPLE.ORG', 'the realm of the source is accepted in any case');

my @refused_principals;
for my $username ('user@OTHER.ORG', 'user@OTHER.ORG@EXAMPLE.ORG', 'user/admin', 'user/admin@EXAMPLE.ORG', 'DOMAIN\\user', '@EXAMPLE.ORG', '') {
    is(authenticated_as($username), undef, "'$username' is refused");
    push @refused_principals, @principals;
}
ok(!@refused_principals, 'without authenticating with Kerberos');

is(authenticated_as('user', ''), undef, 'an empty password is refused');
is(authenticated_as('user', undef), 'user@EXAMPLE.ORG', 'the default test password is used') ;

{
    my $no_realm = pf::Authentication::Source::KerberosSource->new({
        id => 'kerberos_no_realm',
        host => 'kdc.example.org',
        authenticate_realm => '',
    });
    is($no_realm->principal('user'), undef, 'a source without realm refuses the users');
}

is($source->principal(undef), undef, 'an undefined username is refused');

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

#!/usr/bin/perl

=head1 NAME

LDAP

=head1 DESCRIPTION

unit test for pf::LDAP

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 8;

#This test will running last
use Test::NoWarnings;

use pf::LDAP;

# Capture the IO::Socket::SSL arguments Net::LDAP builds for the handshake
my %ssl_args;

{
    package LDAPTest::Message;
    sub new { bless {}, shift }
    sub is_error { 1 }
    sub code { 1 }
    sub server_error { 'mocked' }
    sub error { 'mocked' }

    package LDAPTest::Conn;
    sub new { bless {}, shift }
    sub start_tls {
        my ($self, %arg) = @_;
        $arg{sslserver} = 'containers-gateway.internal' unless defined $arg{sslserver};
        %ssl_args = Net::LDAP::_SSL_context_init_args(\%arg);
        return LDAPTest::Message->new;
    }
    sub unbind { }
    sub disconnect { }
    sub host { 'containers-gateway.internal' }
    sub port { 40389 }
}

no warnings qw(redefine once);
local *Net::LDAPS::new = sub {
    my ($class, $host, %arg) = @_;
    %ssl_args = Net::LDAP::_SSL_context_init_args({ sslserver => $host, %arg });
    $@ = 'mocked';
    return undef;
};
local *Net::LDAP::new = sub { LDAPTest::Conn->new };
use warnings;

sub connect_with {
    my (%args) = @_;
    %ssl_args = ();
    pf::LDAP->compute_connection('containers-gateway.internal', { port => 40389, %args }, []);
    return \%ssl_args;
}

my $ssl = connect_with(encryption => 'ssl', verify => 'require', sslserver => 'ldap.example.com');
is($ssl->{SSL_verifycn_name}, 'ldap.example.com', "ldaps verifies the given server name");
is($ssl->{SSL_hostname}, 'ldap.example.com', "ldaps sends the given server name as SNI");

$ssl = connect_with(encryption => 'ssl', verify => 'require', sslserver => '192.0.2.10');
ok(!exists $ssl->{SSL_hostname}, "no SNI for an IP address");

$ssl = connect_with(encryption => 'ssl', verify => 'require');
ok(!exists $ssl->{SSL_hostname}, "no SNI override without a server name");

$ssl = connect_with(encryption => 'starttls', start_tls_options => { verify => 'require', sslserver => 'ldap.example.com' });
is($ssl->{SSL_verifycn_name}, 'ldap.example.com', "starttls verifies the given server name");
is($ssl->{SSL_hostname}, 'ldap.example.com', "starttls sends the given server name as SNI");

%ssl_args = Net::LDAP::_SSL_context_init_args({ verify => 'require', sslserver => 'ldap.example.com' });
ok(!exists $ssl_args{SSL_hostname}, "Net::LDAP is restored after the connection");

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

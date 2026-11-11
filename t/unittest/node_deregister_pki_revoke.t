#!/usr/bin/perl

=head1 NAME

node_deregister_pki_revoke

=head1 DESCRIPTION

node_deregister revokes the certificate of the node by CN when the PKI
provider has revoke_on_unregistration enabled, except when pfpki deregisters
the devices of a certificate it just revoked (skip_pki_revoke): revoking by CN
again would revoke the next certificate of the same CN (#8017).

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 7;
use Test::NoWarnings;
use pf::node;
use pf::config qw(%Config);

my @revoked;
my %modified;
{
    package t::PkiProvider;
    sub new { bless {}, shift }
    sub revoke_on_unregistration { 'enabled' }
    sub user_cn { $_[1]{pid} }
    sub revoke { push @revoked, $_[1] }

    package t::Provisioner;
    sub new { bless {}, shift }
    sub getPkiProvider { t::PkiProvider->new }

    package t::Profile;
    sub new { bless {}, shift }
    sub findProvisioner { t::Provisioner->new }
}

{
    no warnings qw(redefine once);
    *pf::Connection::ProfileFactory::instantiate = sub { t::Profile->new };
    *pf::node::node_view = sub { { mac => $_[0], pid => 'bob' } };
    *pf::node::node_modify = sub { my ($mac, %info) = @_; %modified = %info; 1 };
}
local $Config{services}{pfdhcp} = 'disabled';

my $mac = '02:44:45:4c:80:17';

ok(pf::node::node_deregister($mac), 'node deregistered');
is_deeply(\@revoked, ['bob'], 'the certificate of the node is revoked by CN on unregistration');

@revoked = ();
ok(pf::node::node_deregister($mac, skip_pki_revoke => 1), 'node deregistered for a revoked certificate');
is_deeply(\@revoked, [], 'no other certificate of the CN is revoked when pfpki deregisters the node');
ok(!exists $modified{skip_pki_revoke}, 'skip_pki_revoke is not stored in the node');
is($modified{status}, 'unreg', 'the node is unregistered');

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

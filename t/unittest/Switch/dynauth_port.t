#!/usr/bin/perl

=head1 NAME

dynauth_port

=head1 DESCRIPTION

The disconnectPort and coaPort of a switch entry are used for every RADIUS
Disconnect-Request and CoA-Request (#4749).

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

use Test::More tests => 7;
use pf::Switch;

#This test will running last
use Test::NoWarnings;

my @sent;
{
    no warnings 'redefine';
    *pf::Switch::perform_disconnect = sub { push @sent, ['disconnect', { %{$_[0]} }]; return { Code => 'Disconnect-ACK' } };
    *pf::Switch::perform_coa = sub { push @sent, ['coa', { %{$_[0]} }]; return { Code => 'CoA-ACK' } };
    *pf::Switch::mark_as_seen = sub { };
}

sub sent_port {
    my ($switch, $method, $connection_info) = @_;
    @sent = ();
    $switch->$method($connection_info // {}, {});
    return $sent[0][1]{nas_port};
}

my $switch = pf::Switch->new({ id => '10.0.0.1', ip => '10.0.0.1', disconnectPort => 1700, coaPort => 1701 });

is(sent_port($switch, 'handleRadiusDisconnect'), 1700, "Disconnect-Request goes to disconnectPort");
is(sent_port($switch, 'handleRadiusCoa'), 1701, "CoA-Request goes to coaPort");
is(sent_port($switch, 'handleRadiusDisconnect', { nas_port => 4000 }), 4000, "a port chosen by the module is kept");

my $no_coa_port = pf::Switch->new({ id => '10.0.0.2', ip => '10.0.0.2', disconnectPort => 1700 });
is(sent_port($no_coa_port, 'handleRadiusCoa'), undef, "CoA-Request does not use disconnectPort");

my $defaults = pf::Switch->new({ id => '10.0.0.3', ip => '10.0.0.3', disconnectPort => '', coaPort => '' });
is(sent_port($defaults, 'handleRadiusDisconnect'), undef, "no port configured leaves the 3799 default to perform_dynauth");
is(sent_port($defaults, 'handleRadiusCoa'), undef, "no CoA port configured leaves the 3799 default to perform_dynauth");

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

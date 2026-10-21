#!/usr/bin/perl

=head1 NAME

setAdminStatus

=head1 DESCRIPTION

The Juniper modules bounce a port over the CLI with the Net::Appliance::Session
4 API (#7451): a recording stand-in for Net::Appliance::Session checks the
calls made and that a failure doesn't escape setAdminStatus

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

our (@CALLS, %FAIL);

# Recording stand-in for Net::Appliance::Session, with the version 4 signatures
BEGIN {
    package Net::Appliance::Session;
    $INC{'Net/Appliance/Session.pm'} = __FILE__;
    sub new {
        my ($class, $args) = @_;
        die "new expects a hash ref\n" if ref($args) ne 'HASH';
        die "Missing required arguments: personality, transport\n" if !$args->{personality} || !$args->{transport};
        push @main::CALLS, "new(" . join(", ", map { "$_=$args->{$_}" } sort keys %$args) . ")";
        return bless { configure => 0 }, $class;
    }
    sub connect {
        my ($self, $args) = @_;
        die "connect expects a hash ref\n" if ref($args) ne 'HASH';
        push @main::CALLS, "connect(" . join(", ", sort keys %$args) . ")";
        die "connection refused\n" if $main::FAIL{connect};
    }
    sub begin_configure { push @main::CALLS, "begin_configure"; $_[0]{configure} = 1 }
    sub in_configure_mode { $_[0]{configure} }
    sub cmd {
        my ($self, $command, $options) = @_;
        die "cmd expects a hash ref of options\n" if defined $options && ref($options) ne 'HASH';
        push @main::CALLS, "cmd($command)";
        die "error: commit failed\n" if $command =~ /^commit/ && $main::FAIL{commit};
        if ($command eq 'rollback') { $self->{rolled_back} = 1 }
        return ();
    }
    sub end_configure {
        my ($self) = @_;
        return unless $self->{configure};
        push @main::CALLS, "end_configure";
        # Junos asks for a confirmation when leaving the configure mode with uncommitted changes
        die "Exit with uncommitted changes? [yes,no]\n" if $main::FAIL{commit} && !$self->{rolled_back};
        $self->{configure} = 0;
    }
    sub close { my ($self) = @_; push @main::CALLS, "close"; $self->end_configure }
}

use Test::More tests => 8;

#This test will running last
use Test::NoWarnings;
use pf::Switch::Juniper::EX;

my $switch = pf::Switch::Juniper::EX->new({
    id => '192.0.2.1', ip => '192.0.2.1', mode => 'production',
    cliTransport => 'SSH', cliUser => 'pf', cliPwd => 'secret',
});
{
    no warnings qw(redefine once);
    *pf::Switch::Juniper::getIfName = sub { 'ge-0/0/1' };
}

my @SESSION = ('new(do_configure_mode=1, do_privileged_mode=0, host=192.0.2.1, personality=junos, timeout=20, transport=SSH)', 'connect(password, username)');

sub bounce {
    my ($enable, %fail) = @_;
    local @CALLS;
    local %FAIL = %fail;
    my $result = eval { $switch->setAdminStatus(1, $enable) };
    return ($@ ? "died: $@" : $result, [@CALLS]);
}

my ($result, $calls) = bounce(0);
is($result, 1, 'disable succeeds');
is_deeply($calls, [@SESSION, 'begin_configure', 'cmd(set interfaces ge-0/0/1 disable)', 'cmd(commit comment "admin link status change by PacketFence")', 'end_configure', 'close'], 'disable sends the version 4 sequence');

($result, $calls) = bounce(1);
is_deeply($calls, [@SESSION, 'begin_configure', 'cmd(delete interfaces ge-0/0/1 disable)', 'cmd(commit comment "admin link status change by PacketFence")', 'end_configure', 'close'], 'enable deletes the disable statement');

($result, $calls) = bounce(0, commit => 1);
is($result, undef, 'a failing commit returns undef instead of dying');
is_deeply($calls, [@SESSION, 'begin_configure', 'cmd(set interfaces ge-0/0/1 disable)', 'cmd(commit comment "admin link status change by PacketFence")', 'cmd(rollback)', 'close', 'end_configure'], 'and rolls back the change before leaving the configure mode');

($result, $calls) = bounce(0, connect => 1);
is($result, undef, 'a failing connection returns undef');
is(scalar(grep { /^cmd/ } @$calls), 0, 'and sends no command');

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

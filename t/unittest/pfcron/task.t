#!/usr/bin/perl

=head1 NAME

task

=head1 DESCRIPTION

unit test for task

=cut

use strict;
use warnings;

our @TESTS;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    @TESTS = (
        {
            args  => [],
            type  => 'password_of_the_day',
            setup => \&startSMTP,
            check => sub {
                is(SHM::getCount(),1, "The email was sent");
            }
        },
        {
            args  => [],
            type  => 'person_cleanup',
            setup => \&setup_person_cleanup,
            check => \&check_person_cleanup,
            test_count => 5,
        },
    );
}
use List::Util qw(sum);

use Test::More tests => 2 + (sum map { $_->{test_count} // 2 } @TESTS );

use DateTime;
use Test::NoWarnings;
use pf::api;
use pf::api::local;
use Net::SMTP::Server;
use Net::SMTP::Server::Client;
use Carp;
use Utils;
use pf::AtFork;
use pf::password;
use pf::node qw(node_add);
use IO::Handle;

{

    package SHM;
    use IPC::SysV qw(IPC_PRIVATE S_IRUSR S_IWUSR S_IRWXU);
    use IPC::SharedMem;

    our $SHM = IPC::SharedMem->new(IPC_PRIVATE, 8, S_IRWXU);

    sub getCount {
        my $count_packed = $SHM->read(0, 2);
        return unpack("S",$count_packed);
    }

    sub incCount {
        my $count = getCount();
        $count++;
        $SHM->write(pack("S", $count),0, 2);
    }

    $SHM->write(pack("S", 0), 0, 2);
}

use pf::factory::pfcron::task;

my $smtp_server_pid;

END {
    if ($smtp_server_pid) {
        kill 9, $smtp_server_pid;
    }
}

is(SHM::getCount(), 0, "The SHM is set to zero");

local $pf::config::util::SEND_MAIL_API_CLIENT = 'pf::api::local';

for my $test (@TESTS) {
    my $ctx = {};
    my $task = pf::factory::pfcron::task->new(
        $test->{type},
        @{ $test->{args} // [] },
    );
    ok($task, "creating $test->{type}");
    my $setup = $test->{setup};
    $setup->($ctx) if ($setup);
    $task->run();
    $test->{check}->($ctx);
}

sub startSMTP {
    pipe(my $reader, my $writer);
    my $pid = pf::AtFork::pf_fork();
    BAIL_OUT("Cannot fork") if ( !defined $pid );
    if ($pid) {
        close($writer);
        my $line = <$reader>;
        close($reader);
        pf::password::_delete('potd');
        pf::person::person_delete('potd');
        $smtp_server_pid = $pid;
        return;
    }

    close($reader);
    my $server = new Net::SMTP::Server( 'localhost', 2525 )
      || croak("Unable to handle client connection: $!\n");
    $writer->write("done\n");
    close($writer);
    while ( my $conn = $server->accept() ) {

        my $client = new Net::SMTP::Server::Client($conn)
          || croak("Unable to handle client connection: $!\n");

        SHM::incCount();
        $client->process;
		last;
    }

    exit 0;
}

sub setup_person_cleanup {
    my ($ctx) = @_;
    my $pid1  = Utils::test_pid();
    my $pid2  = Utils::test_pid();
    my $pid3  = Utils::test_pid();
    my $pid4  = Utils::test_pid();
    push @{ $ctx->{to_remove} }, $pid1, $pid3;
    push @{ $ctx->{to_keep} }, $pid2, $pid4;
    pf::person::person_add($pid1);
    pf::person::person_add($pid2);
    pf::person::person_add($pid3);
    pf::person::person_add($pid4);
    my $mac  = Utils::test_mac();
    node_add($mac, pid => $pid4);
    my $now = DateTime->now( time_zone => "local" );
    pf::password::generate(
        $pid2,
        [
            { type => 'valid_from', value => $now },
            {
                type  => 'expiration',
                value => pf::config::access_duration("100s")
            }
        ],
        undef, '0',
        {}
    );

    pf::password::generate(
        $pid3,
        [
            { type => 'valid_from', value => $now },
            {
                type  => 'expiration',
                value => pf::config::access_duration("0s")
            }
        ],
        undef, '0',
        {}
    );
}

sub check_person_cleanup {
    my ($ctx) = @_;
    for my $pid (@{$ctx->{to_remove}}) {
        ok(!pf::person::person_exist($pid), "person $pid does not exists");
    }

    for my $pid (@{$ctx->{to_keep}}) {
        ok(pf::person::person_exist($pid), "person $pid exists");
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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


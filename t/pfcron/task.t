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
        },
    );
}

use Test::More tests => 1 + scalar @TESTS * 2;;

#This test will running last
use Test::NoWarnings;
use Net::SMTP::Server;
use Net::SMTP::Server::Client;
use Carp;
use Utils;
use pf::password;
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

for my $test (@TESTS) {
    my $task = pf::factory::pfcron::task->new(
        $test->{type},
        @{ $test->{args} // [] },
    );
    ok($task, "creating $test->{type}");
    my $setup = $test->{setup};
    $setup->() if ($setup);
    $task->run();
    $test->{check}->();
}

sub startSMTP {
    pipe(my $reader, my $writer);
    my $pid = fork();
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

}

sub check_person_cleanup {

}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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


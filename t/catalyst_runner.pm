package catalyst_runner;

=head1 NAME

catalyst_runner -

=cut

=head1 DESCRIPTION

catalyst_runner

=cut

use strict;
use warnings;
use POSIX;
use Moo;

has app => (
    is       => 'ro',
    required => 1,
);

has server_pid => (
    is  => 'rw',
);

has server => (
    is => 'rw',
);

has port => (
    is => 'rw',
);

has debug => (
    is  => 'rw',
);


sub DESTROY {
    my ($self) = @_;
    if ($self->server_pid) {
        local $?;
        print STDERR "[$$] Waiting for Catalyst server [", $self->server_pid, "] to finish..\n" if $self->debug;
        local $SIG{PIPE} = 'IGNORE';
        kill 15, $self->server_pid;
        close $self->server;
    }
};

sub test_port {
    my ($port) = @_;
    IO::Socket::INET->new(
        Listen    => 5,
        Proto     => 'tcp',
        Reuse     => 1,
        LocalPort => $port
    );
}

sub start_catalyst_server {
    my ($self) = @_;

    my $pid;
    if (my $pid = open my $server, '-|') {
        $self->server_pid($pid);
        $self->server($server);
        my $port = <$server>;
        chomp $port;
        my $status = <$server>;
        chomp $status;
        return $port, $status;
    }
    else {
        require Catalyst::ScriptRunner;
        require Catalyst::Script::Server;
        require HTTP::Server::PSGI;

        my $css_pla = \&Catalyst::Script::Server::_plack_loader_args;
        my $new_css_pla = sub {
            my %args = $css_pla->(@_);
            my $sr = delete $args{server_ready};
            $args{server_ready} = sub {
                print "ready\n";
                $sr ? $sr->(@_) : ();
            };
            return %args;
        };

        my $css_run = \&Catalyst::Script::Server::_run_application;
        my $new_css_run = sub {
            my $ret;
            eval { $ret = $css_run->(@_); };
            if ( $@ ) {
                my $msg = $@;
                print STDERR "$@\n";
                print "fail\n";
                die $@;
            } else {
                return $ret;
            }
        };

        # avoid race condition between testing and using port
        my $socket;
        my $hsp_sl = \&HTTP::Server::PSGI::setup_listener;
        my $new_hsp_sl = sub {
            my $self = shift;
            $self->{listen_sock} = $socket;
            return $hsp_sl->($self,@_);
        };

        {
            no warnings 'redefine';
            *Catalyst::Script::Server::_plack_loader_args = $new_css_pla;
            *Catalyst::Script::Server::_run_application   = $new_css_run;
            *HTTP::Server::PSGI::setup_listener           = $new_hsp_sl;
        }

        my ($port, $catalyst) = (4000);
        while (1) {
            $port++, next unless $socket = test_port($port);
            print STDERR "[$$] Starting Catalyst server on port $port..\n" if $self->debug;
            print "$port\n";
            @ARGV = ('-p', $port);
            Catalyst::ScriptRunner->run($self->app, 'Server');
            print STDERR "[$$] Catalyst server exited early, aborting\n" if $self->debug;
            print "fail\n";
            POSIX::_exit 0;
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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


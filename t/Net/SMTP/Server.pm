package Net::SMTP::Server;

require 5.001;

use strict;
use vars qw($VERSION @ISA @EXPORT);

require Exporter;
require AutoLoader;
use Carp;
use IO::Socket;
use Sys::Hostname;

@ISA = qw(Exporter AutoLoader);
@EXPORT = qw();

$VERSION = '1.1';

sub new {
    my $this = shift;
    
    my $class = ref($this) || $this;
    my $self = {};

    $self->{HOST} = shift;
    $self->{PORT} = shift;
    
    bless($self, $class);
    
    $self->{HOST} = hostname unless defined($self->{HOST});
    $self->{PORT} = 25 unless defined($self->{PORT});

    $self->{SOCK} = IO::Socket::INET->new(Proto => 'tcp',
					  LocalAddr => $self->{HOST},
					  LocalPort => $self->{PORT},
					  Listen    => SOMAXCONN,
					  Reuse     => 1);
    
    return defined($self->{SOCK}) ? $self : undef;
}

sub accept {
    my $self = shift;
    my $client;
    
    if($client = $self->{SOCK}->accept()) {
	$self->{SOCK}->autoflush(1);
	return $client;
    }
    
    return undef;
}

sub DESTROY {
    shift->{SOCK}->close;
}

1;
__END__
# POD begins here.

=head1 NAME

Net::SMTP::Server - A native Perl SMTP Server implementation for Perl.

=head1 SYNOPSIS

  use Carp;
  use Net::SMTP::Server;
  use Net::SMTP::Server::Client;
  use Net::SMTP::Server::Relay;

  $server = new Net::SMTP::Server('localhost', 25) ||
    croak("Unable to handle client connection: $!\n");

  while($conn = $server->accept()) {
    # We can perform all sorts of checks here for spammers, ACLs,
    # and other useful stuff to check on a connection.

    # Handle the client's connection and spawn off a new parser.
    # This can/should be a fork() or a new thread,
    # but for simplicity...
    my $client = new Net::SMTP::Server::Client($conn) ||
	croak("Unable to handle client connection: $!\n");

    # Process the client.  This command will block until
    # the connecting client completes the SMTP transaction.
    $client->process || next;
    
    # In this simple server, we're just relaying everything
    # to a server.  If a real server were implemented, you
    # could save email to a file, or perform various other
    # actions on it here.
    my $relay = new Net::SMTP::Server::Relay($client->{FROM},
					     $client->{TO},
					     $client->{MSG});
  }

=head1 DESCRIPTION

The Net::SMTP::Server module implements an RFC 821 compliant SMTP
server, completely in Perl.  It's extremely extensible, so adding in
things like spam filtering, or more advanced routing and handling
features can be easily handled.  An additional module,
Net::SMTP::Server::Relay has also been implemented as an example of
just one application of this extensibility.  See the pod for more
details on that module.  This extension has been tested on both Unix
and Win32 platforms.

Creating a new server is as trivial as:

  $server = new Net::SMTP::Server($host, $port);

This creates a new SMTP::Server.  Both $host and $port are optional,
and default to the current hostname and the standard SMTP port (25).
However, if you run on a multi-homed machine, you may want to
explicitly specify which interface to bind to.

The server loop should look something like this:

  while($conn = $server->accept()) {
    my $client = new Net::SMTP::Server::Client($conn) ||
	croak("Unable to handle client connection: $!\n");    

    $client->process;
  }

The server will continue to accept connections forever.  Once we have
a connection, we create a new Net::SMTP::Server::Client.  This is a
new client connection that will now be handled.  The reason why
processing doesn't begin here is to allow for any extensibility or
hooks a user may want to add in after we've accepted the client
connection, but before we give the initial welcome message to the
client.  Once we're ready to process an SMTP session, we call
$client->process.  This may HANG while the SMTP transaction takes
place, as the client and server are communicating back and forth (and
if there's a lot of data to transmit, well...).

Once $client->process returns, various fields have been filled in.
Those are:

  $client->{TO}    -- This is an array containing the intended
                      recipients for this message.  There may be
                      multiple recipients for any given message.

  $client->{FROM}  -- This is the sender of the given message.
  $client->{MSG}   -- The actual message data. :)

The SMTP::Server module performs no other processing for the user.
It's meant to give you the building blocks of an extensible SMTP
server implementation.  For example, using the MIME modules, you can
easily process $client->{MSG} to handle MIME attachments, etc.  Or you
could implement ACLs to control who can connect to the server, or what
actions are taken.  Finally, a suggested use that the author himself
uses, is as an SMTP relay.  There are lots of times I need access to
an SMTP server just to send a message, but don't have access to one
for whatever reason (firewalls, permissions, etc).  You can run your
own SMTP server whether under Unix or Win32 environments, and simply
point your favorite mail client to it when sending messages.  See the
Net::SMTP::Server::Relay modules for details on that use.

=head1 AUTHOR AND COPYRIGHT
Net::SMTP::Server / SMTP::Server is Copyright(C) 1999,
  MacGyver (aka Habeeb J. Dihu) <macgyver@tos.net>.  ALL RIGHTS RESERVED.

You may distribute this package under the terms of either the GNU
General Public License or the Artistic License, as specified in the
Perl README file.

=head1 SEE ALSO

Net::SMTP::Server::Client, Net::SMTP::Server::Relay

=cut

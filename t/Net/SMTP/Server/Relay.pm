package Net::SMTP::Server::Relay;

require 5.001;

use strict;
use vars qw($VERSION @ISA @EXPORT);

require Exporter;
require AutoLoader;
use Carp;
use Net::DNS;
use Net::Domain qw(hostdomain);
use Net::SMTP;

@ISA = qw(Exporter AutoLoader);
@EXPORT = qw();

$VERSION = '1.1';

sub _relay {
    my $self = shift;
    my $target;
    
    # Loop through the recipient list.
    foreach $target (@{$self->{TO}}) {
	my $rr;
	my $domain = /@(.*)/;
	my $res = new Net::DNS::Resolver;
	my @mx = mx($res, defined($1) ? $1 : hostdomain);
	
	next unless defined(@mx);
	
	# Loop through the MXs.
	foreach $rr (@mx) {
	    my $client = new Net::SMTP($rr->exchange) || next;
	    
	    $client->mail($self->{FROM});
	    $client->to($target);
	    $client->data($self->{MSG});
	    $client->quit;
	    
	    last;
	}
    }
}

# New instance.
sub new {
    my($this, $tmpto) = undef;

    $this = $_[0];
    
    my $class = ref($this) || $this;
    my $self = {};

    $self->{FROM} = $_[1];
    $self->{TO} = $_[2];
    $self->{MSG} = $_[3];

    bless($self, $class);    
    croak("Bad format.") unless defined($self->{MSG});
    
    $self->_relay;

    return $self;
}

1;
__END__
# POD begins here.

=head1 NAME

Net::SMTP::Server::Relay - A simple relay module for Net::SMTP::Server.

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

The Net::SMTP::Server::Relay module implements simple SMTP relaying
for use with the Net::SMTP::Server module.  All this module does is to
take a given message and iterate through the list of recipients, doing 
DNS lookups for the associated MX record and delivering the messages.
This module makes extensive use of the plethora of other modules
already implemented for Perl (specifically the DNS and Net::SMTP
modules in this case), and should give but a glimpse of the potential
for extending the Net::SMTP::Server's functionality to provide a
full-featured SMTP server, native to Perl.

The above example illustrates the use of the Net::SMTP::Server::Relay
modules -- you simply have to instantiate the module, passing along
the sender, recipients, and message.  More formally:

  $relay = new Net::SMTP::Server::Relay($from, @to, $msg);

Where $from is the sender, @to is an array containing the list of
recipients, and $msg is the message to relay.

=head1 AUTHOR AND COPYRIGHT
Net::SMTP::Server / SMTP::Server is Copyright(C) 1999, 
  MacGyver (aka Habeeb J. Dihu) <macgyver@tos.net>.  ALL RIGHTS RESERVED.

You may distribute this package under the terms of either the GNU
General Public License or the Artistic License, as specified in the
Perl README file. 

=head1 SEE ALSO

Net::SMTP::Server::Server, Net::SMTP::Server::Client

=cut

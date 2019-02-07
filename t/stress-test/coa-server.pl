#!/usr/bin/perl

=head1 NAME

coa-server.pl

=head1 DESCRIPTION

Modified version of example-yes.pl taken from
https://metacpan.org/source/LUISMUNOZ/Net-Radius-2.103/examples/example-yes.pl

This is a VERY simple RADIUS CoA server which responds with some of the data
in the request. It was built to do load testing and to validate that we can
use the CoA code in a multithreaded context without issues.

=cut
 
use warnings;
use strict;

use Fcntl;
use Net::Radius::Dictionary;
use Net::Radius::Packet;
use Net::UDP;

my $secret = "qwerty";  # Shared secret on the term server. This seems to be ignored actually.
 
# Parse the RADIUS dictionary file (must have dictionary in current dir)
my $dict = new Net::Radius::Dictionary "/usr/local/pf/lib/pf/util/dictionary"
  or die "Couldn't read dictionary: $!";
 
# Set up the network socket (must have radius-dynauth in /etc/services)
my $s = new Net::UDP { thisservice => "radius-dynauth" } or die $!;
$s->bind or die "Couldn't bind: $!";
$s->fcntl(F_SETFL, $s->fcntl(F_GETFL,0) | O_NONBLOCK)
  or die "Couldn't make socket non-blocking: $!";
 
# Loop forever, receiving packets and replying to them
while (1) {
  my ($rec, $whence);
  # Wait for a packet
  my $nfound = $s->select(1, 0, 1, undef);
  if ($nfound > 0) {
    # Get the data
    $rec = $s->recv(undef, undef, $whence);
    # Unpack it
    my $p = new Net::Radius::Packet $dict, $rec;
    # Create a response packet
    my $rp = new Net::Radius::Packet $dict;

    if ( my ($request_type) = $p->code =~ /(CoA|Disconnect)-Request/ ) {

      $rp->set_code("$request_type-ACK");
      $rp->set_identifier($p->identifier);
      $rp->set_authenticator($p->authenticator);
      $rp->set_attr('Reply-Message' => $p->attr('Calling-Station-Id'));
      #$rp->set_attr('Error-Cause' => 404);

    } else {

      # It's not an CoA-Request
      print "Unexpected packet type recieved.\n";

      # Create a response packet
      $rp->set_code("$request_type-NAK");
      $rp->set_identifier($p->identifier);
      $rp->set_authenticator($p->authenticator);
      $rp->set_attr('Error-Cause' => 404);

    }

    # printing debug information
    print "Request\n";
    print "=======\n";
    $p->dump;
    print "Response\n";
    print "========\n";
    $rp->dump;

    # send response
    $s->sendto(auth_resp($rp->pack, $secret), $whence);
  }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Luis E. Muñoz <luismunoz@cpan.org>.

Christopher Masto. 

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

Changes (c) 2002,2003 Luis E. Muñoz <luismunoz@cpan.org>.

Original work (c) Christopher Masto. 

=head1 LICENSE

This software can be used under the same terms as perl itself. It also
carries the same warranties.

=cut

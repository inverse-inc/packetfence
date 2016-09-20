# ======================================================================
#
# Copyright (C) 2007 Martin Kutter.
# Part of SOAP-Lite, Copyright (C) 2000-2001 Paul Kulchenko 
#  (paulclinger@yahoo.com)
# You may distribute/modify this file under the same terms as perl itself.
#
# $ID: $
#
# ======================================================================

package SOAP::Transport::LOOPBACK;
use strict;

package SOAP::Transport::LOOPBACK::Client;
use strict;

use vars qw(@ISA);
@ISA = qw(SOAP::Client);

sub new {
    my $class = ref $_[0] || $_[0];
    return bless {}, $class;
}

sub send_receive {
    my($self, %parameters) = @_;
    
    $self->code(200);
    $self->message('OK');
    $self->is_success(1);
    $self->status('200 OK');

    return $parameters{envelope};
}

1;

__END__

=pod

=head1 NAME 

SOAP::Transport::LOOPBACK - Test loopback transport backend (Client only) 

=head1 DESCRIPTION

SOAP::Transport::LOOPBACK is a test transport backend for SOAP::Lite.

It just returns the XML request as response, thus allowing to test the 
complete application stack of client applications from the front end down to 
the transport layer without actually sending data over the wire.  

Using this transport backend is triggered by setting a loopback:// URL.

Sending requests through this transport backend alway succeeds with the 
following states:

 status: 200 OK
 code: 200
 message: OK 

=head1 COPYRIGHT

Copyright (C) 2007 Martin Kutter. All rights reserved.

This file is part of SOAP-Lite, Copyright (C) 2000-2001 Paul Kulchenko.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Martin Kutter E<lt>martin.kutter fen-net.deE<gt>

=cut

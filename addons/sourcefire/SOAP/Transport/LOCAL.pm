# ======================================================================
#
# Copyright (C) 2000-2001 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: LOCAL.pm 374 2010-05-14 08:12:25Z kutterma $
#
# ======================================================================

package SOAP::Transport::LOCAL;

use strict;


our $VERSION = 0.712;

# ======================================================================

package SOAP::Transport::LOCAL::Client;

use SOAP::Lite;

use vars qw(@ISA);
@ISA = qw(SOAP::Client SOAP::Server);

sub new { 
    my $class = shift;
    return $class if ref $class;
    my(@arg_from, @method_from);
    while (@_) {
        $class->can($_[0])
            ? push(@method_from, shift() => shift)
            : push(@arg_from, shift)
    }
    my $self = $class->SUPER::new(@arg_from);
    $self->is_success(1);     # it's difficult to fail in this module
    $self->dispatch_to(@INC);
    while (@method_from) {
        my($method, $param_ref) = splice(@method_from,0,2);
        $self->$method(ref $param_ref eq 'ARRAY'
            ? @$param_ref
            : $param_ref) 
    }
    return $self;
}

sub send_receive {
    my($self, %parameters) = @_;
    my($envelope, $endpoint, $action) = 
        @parameters{qw(envelope endpoint action)};

    SOAP::Trace::debug($envelope);
    my $response = $self->SUPER::handle($envelope);
    SOAP::Trace::debug($response);

    return $response;
}

# ======================================================================

1;

__END__

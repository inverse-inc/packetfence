# ======================================================================
#
# Copyright (C) 2000-2001 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: IO.pm 374 2010-05-14 08:12:25Z kutterma $
#
# ======================================================================

package SOAP::Transport::IO;

use strict;

our $VERSION = 0.712;

use IO::File;
use SOAP::Lite;
# ======================================================================

package SOAP::Transport::IO::Server;

use strict;
use Carp ();
use vars qw(@ISA);
@ISA = qw(SOAP::Server);

sub new {
    my $class = shift;

    return $class if ref $class;
    my $self = $class->SUPER::new(@_);

    return $self;
}

sub in {
    my $self = shift;
    $self = $self->new() if not ref $self;

    return $self->{ _in } if not @_;

    my $file = shift;
    $self->{_in} = (defined $file && !ref $file && !defined fileno($file))
        ? IO::File->new($file, 'r')
        : $file;
    return $self;
}

sub out {
    my $self = shift;
    $self = $self->new() if not ref $self;

    return $self->{ _out } if not @_;

    my $file = shift;
    $self->{_out} = (defined $file && !ref $file && !defined fileno($file))
        ? IO::File->new($file, 'w')
        : $file;
    return $self;
}

sub handle {
    my $self = shift->new;

    $self->in(*STDIN)->out(*STDOUT) unless defined $self->in;
    my $in = $self->in;
    my $out = $self->out;

    my $result = $self->SUPER::handle(join '', <$in>);
    no strict 'refs';
    print {$out} $result
        if defined $out;
    return;
}

# ======================================================================

1;

__END__

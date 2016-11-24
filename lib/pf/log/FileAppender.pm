package pf::log::FileAppender;
use base qw( Log::Log4perl::Appender::File );
use strict;
use warnings;

sub log {
     my($self, @args) = @_;

     local $Log::Log4perl::caller_depth =
           $Log::Log4perl::caller_depth + 1;

     eval { $self->SUPER::log(@args) };
}

1;

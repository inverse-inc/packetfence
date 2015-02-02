package zicache::namespaces::resource;

use strict;
use warnings;
use Data::Dumper;

sub new {
  my ($class, $cache) = @_;
  my $self = bless {}, $class;

  $self->{cache} = $cache;

  $self->init();

  return $self;
}

sub init {
  my ($self) = @_;
  return undef;
}

sub build {
  my ($self) = @_;
  return undef;
}

1;

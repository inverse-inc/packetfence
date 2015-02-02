package zicache::namespaces::resource::default_switch;

use strict;
use warnings;
use Data::Dumper;

use base 'zicache::namespaces::resource';

sub init {
  my ($self) = @_;
  $self->{switches} = $self->{cache}->get_cache('config::Switch');
}

sub build {
  my ($self) = @_;
  return $self->{switches}{default};
}

1;

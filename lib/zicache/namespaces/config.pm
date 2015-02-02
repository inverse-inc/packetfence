package zicache::namespaces::config;

use Data::Dumper;

use base 'zicache::namespaces::resource';

sub build {
  my ($self) = @_;

  tie %tmp_cfg, 'Config::IniFiles', ( -file => $self->{file} );

  $self->{cfg} = \%tmp_cfg;

  my $child_resource = $self->build_child();
  return $child_resource;
}

sub init {
  # abstact
}

sub build_child {
  # abstract
}

1;

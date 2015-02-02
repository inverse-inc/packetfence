package zicache::namespaces::config;

use Data::Dumper;

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;

  $self->init();

  return $self;
}

sub build {
  my ($self) = @_;

  tie %tmp_cfg, 'Config::IniFiles', ( -file => $self->{file} );

  $self->{cfg} = \%tmp_cfg;

  my $child_resource = $self->build_child();
  return $child_resource;
}

sub build_child {
  my ($self) = @_;
  return undef;
}

sub init {
  # abstact
}

sub build_child {
  # abstract
}

1;

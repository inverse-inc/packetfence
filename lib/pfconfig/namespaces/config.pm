package pfconfig::namespaces::config;

use strict;
use warnings;

use Data::Dumper;

use base 'pfconfig::namespaces::resource';

sub build {
  my ($self) = @_;

  my %tmp_cfg;

  tie %tmp_cfg, 'Config::IniFiles', ( -file => $self->{file} );

  $self->{cfg} = \%tmp_cfg;

  my $child_resource = $self->build_child();
  return $child_resource;
}

1;

package pf::config::cached;
=head1 NAME

pf::config::cached

=cut

=head1 DESCRIPTION

A module to provide a layer for reading a cached config

=cut

use strict;
use warnings;
use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";
use CHI;
use Config::IniFiles;
use Moose;

has configFile => (
    is => 'ro',
    'required' => 1,
);

has cache => (
    is => 'ro',
    lazy => 1,
    builder => '_cache_builder'
);

=head2 Methods

=over

=item _cache_builder

builds the CHI cache object

=cut

sub _cache_builder {
    my ($self) = @_;
    return CHI->new(
        driver => 'Memcached',   # or 'Memcached::Fast', or 'Memcached::libmemcached'
        namespace => ref($self) || $self ,
        servers => ['localhost:11211'],
        l1_cache => {
            driver => 'RawMemory', global => 1
        }
    );
}


=item _expire_if

check to see if the config file needs to be reread

=cut

sub _expire_if {
    my ($cache_object) = @_;
    return $cache_object->created_at < (stat($cache_object->key()))[9];
}


=item config

gets the current copy of the cached config

=cut

sub config {
    my ($self) = @_;
    my $file_name = $self->configFile;
    return $self->cache->compute($file_name,
        {
            expire_if => \&_expire_if
        } ,
        sub {
            my %ini;
            my $ini_conf = tie %ini, 'Config::IniFiles', ( -file => $file_name,-allowempty => 1);
            my %config;
            foreach my $section (keys %ini) {
                my %section_hash = %{$ini{$section}};
                $config{$section} = \%section_hash;
            }
            $ini_conf  = undef;
            untie (%ini);
            $self->fixupConfig(\%config);
            return \%config;
        }
    );
}

=item fixupConfig

allows configuration to be modified before being stored

=cut

sub fixupConfig { }

sub TIEHASH {
    my ($proto,@args) = @_;
    my $class = ref($proto) || $proto;
    return $class->new(@args);
}

sub FETCH {
  my($self,$key) = @_;
  my $config = $self->config;
  return if (!exists $config->{$key});

  return $config->{$key};
} # end FETCH


sub STORE {
  my($self,$key,$value) = @_;
  my $config = $self->config;
  return undef unless ref($value) eq 'HASH';
  $config->{$key} = $value;
  return 1;
} # end STORE

sub DELETE {
  my($self,$key) = @_;
  return delete $self->config->{$key};
}

sub EXISTS {
  my($self,$key) = @_;
  return exists $self->config->{$key};
}

sub CLEAR {
  my($self) = @_;
  %{$self->config} = ();
}

sub FIRSTKEY {
    my($self) = @_;
    my $config = $self->config;
    my $a = scalar keys %{$config};
    each %{$config}
}

sub NEXTKEY {
    my($self) = @_;
    my $config = $self->config;
    each %{$config}
}

sub SCALAR {
  my($self) = @_;
  scalar %{$self->config};
}

__PACKAGE__->meta->make_immutable;

=back

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

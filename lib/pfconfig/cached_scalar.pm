package pfconfig::cached_scalar;

=head1 NAME

pfconfig::cached_scalar

=cut

=head1 DESCRIPTION

pfconfig::cached_scalar

This module serves as an interface to create an object that
will proxy it's access to the pfconfig service

It is used as a bridge between a pfconfig namespace element
and an object without having a memory footprint unless when
the object is used

=cut

=head1 USAGE

This class is used with tiying

Example : 
my $object;
tie $object, 'pfconfig::cached_scalar', 'resource::fqdn';
print $hash{_ip};

This ties $object to the namespace 'resource::fqdn' defined in
lib/pfconfig/namespaces/ and served though pfconfig

In order to call a method on this tied object 
my $zammit = tied($object)->zammit

=cut

use strict;
use warnings;

use Tie::Scalar;
use IO::Socket::UNIX qw( SOCK_STREAM );
use pfconfig::timeme;
use Data::Dumper;
use pfconfig::log;
use pfconfig::cached;
our @ISA = ('Tie::Scalar', 'pfconfig::cached');

# constructor of the object
sub TIESCALAR {
  my ($class, $config) = @_;
  my $self = bless {}, $class;

  $self->init();

  $self->{"_namespace"} = $config;
  
  $self->{element_socket_method} = "element";

  return $self;
}

# accessor of the object
sub FETCH {
  my ($self) = @_;
  my $logger = get_logger;

  my $subcache_value = $self->get_from_subcache("myself");
  return $subcache_value if defined($subcache_value); 

  my $reply = $self->_get_from_socket("$self->{_namespace}");
  my $result = defined($reply) ? $self->_get_from_socket("$self->{_namespace}")->{element} : undef;

  $self->set_in_subcache("myself", $result);

  return $result;

}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:


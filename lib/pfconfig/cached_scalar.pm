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
use pf::log;
use pfconfig::cached;
our @ISA = ( 'Tie::Scalar', 'pfconfig::cached' );

=head2 TIESCALAR

Constructor of the object

=cut

sub TIESCALAR {
    my ($class, $config, %extra) = @_;
    my $self = bless { }, $class;
    $self->init();
    $self->set_namespace($config);
    $self->{"_scoped_by_tenant_id"} = $extra{tenant_id_scoped};
    $self->{"_control_file_path"} = pfconfig::util::control_file_path($self->{_namespace});
    $self->{"element_socket_method"} = "element";
    return $self;
}

=head2 FETCH

Accesses the object
Will serve it from it's subcache if it has it and it's still has it
Other than that it proxies the call to pfconfig

=cut

sub FETCH {
    my ($self) = @_;
    my $logger = $self->logger;

    my $subcache_value = $self->get_from_subcache("myself");
    return $subcache_value if defined($subcache_value);

    my $reply = $self->_get_from_socket("$self->{_namespace}");
    my $result = defined($reply) ? $self->_get_from_socket("$self->{_namespace}")->{element} : undef;

    $self->set_in_subcache( "myself", $result );

    return $result;
}

=head2 STORE

Log attempts to store something in a pfconfig::cached_scalar

=cut

sub STORE {
    my ($self) = @_;
    $self->logger->logcroak("Trying to store a value in $self->{_namespace}");
    return ;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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


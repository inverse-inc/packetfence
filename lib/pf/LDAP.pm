package pf::LDAP;

=head1 NAME

pf::LDAP - Cache LDAP connections

=cut

=head1 DESCRIPTION

pf::LDAP

=cut

use strict;
use warnings;

use CHI;
use Net::LDAP;
use Net::LDAPS;
# available encryption
use constant {
    NONE => "none",
    SSL => "ssl",
    TLS => "starttls",
};

our $CHI_CACHE = CHI->new(driver => 'RawMemory', datastore => {});


=head2 new

Get or create a cached ldap connection

=cut

sub new {
    my ($class, @args) = @_;
    return $CHI_CACHE->compute(\@args, { expire_if => sub { $class->expire_if(@_) } }, sub { $class->compute_connection(@args) });
}

=head2 expire_if

Checks to see if the the LDAP connection is still alive

=cut

sub expire_if {
    my ($self, $object, $driver) = @_;
    my $ldap = $object->value;
    my $msg = $ldap->bind;
    return 1 if !defined $msg;
    return !defined $msg || $msg->is_error;
}

=head2 compute_connection

Create the connection for connecting to LDAP

=cut

sub compute_connection {
    my ($class, $server, %args) = @_;
    my $encryption = delete $args{encryption};
    my $connection;
    if ( $encryption eq SSL ) {
        $connection = Net::LDAPS->new($server, %args);
    } else {
        $connection = Net::LDAP->new($server, %args);
    }
    return $connection;
}

=head2 CLONE

Clear the cache in a thread environment

=cut

sub CLONE {
    $CHI_CACHE->clear;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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


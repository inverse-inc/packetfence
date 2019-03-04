package pfconfig::namespaces::interfaces::dhcpd_ints;

=head1 NAME

pfconfig::namespaces::interfaces::dhcpd_ints

=cut

=head1 DESCRIPTION

Return all the interfaces where pfdhcpd must run

=cut

use strict;
use warnings;

use base 'pfconfig::namespaces::interfaces';

sub init {
    my ($self, $host_id) = @_;
    $self->{_interfaces} = defined($host_id) ? $self->{cache}->get_cache("interfaces($host_id)") : $self->{cache}->get_cache("interfaces");
}

sub build {
    my ($self) = @_;
    my $interfaces = $self->{_interfaces};
    return $interfaces->{dhcpd_ints} // [];
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

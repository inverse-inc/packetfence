package pfconfig::namespaces::resource::domain_dns_servers;

=head1 NAME

pfconfig::namespaces::resource::domain_dns_servers

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::domain_dns_servers

This module create an associative hash between a domain and it's DNS server

=cut

use strict;
use warnings;
use pf::util;

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;

    # we depend on the switch configuration object (russian doll style)
    $self->{domains} = $self->{cache}->get_cache('config::Domain');
}

sub build {
    my ($self) = @_;
    my %ConfigDomain = %{$self->{domains}};
    my %domain_dns_servers;
    foreach my $key ( keys %ConfigDomain ) {
        $domain_dns_servers{$ConfigDomain{$key}->{dns_name}} = [ split(/\s*,\s*/, $ConfigDomain{$key}->{dns_servers}) ] if (isenabled($ConfigDomain{$key}->{registration}));
    }
    return \%domain_dns_servers;
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


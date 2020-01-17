package pfconfig::namespaces::resource::tls_config;

=head1 NAME

pfconfig::namespaces::resource::tls_config

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::tls_config

=cut

use strict;
use warnings;
use pf::util;

use base 'pfconfig::namespaces::resource';
use pfconfig::namespaces::config::Tls;
use pfconfig::namespaces::config::Ssl;
use pfconfig::namespaces::config::Ocsp;

sub init {
    my ($self) = @_;

    $self->{ssl} = $self->{cache}->get_cache("config::Ssl");
    $self->{ocsp} = $self->{cache}->get_cache("config::Ocsp");
    $self->{tls} = $self->{cache}->get_cache("config::Tls");

}

sub build {
    my ($self) = @_;

    my %ConfigTls;

    foreach my $tls ( keys %{$self->{tls}} ) {
        foreach my $key ( keys %{$self->{tls}{$tls}} ) {
            if ($key eq "certificate_profile") {
                 $ConfigTls{$tls}{$key} = $self->{ssl}{$self->{tls}{$tls}{$key}};
             } elsif ($key eq "ocsp") {
                 $ConfigTls{$tls}{$key} = $self->{oscp}{$self->{tls}{$tls}{$key}};
             } else {
                 $ConfigTls{$tls}{$key} = $self->{tls}{$tls}{$key};
             }
         }
    }
    return \%ConfigTls;
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


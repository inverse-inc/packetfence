package pfconfig::namespaces::resource::connectors_config;

=head1 NAME

pfconfig::namespaces::resource::connectors_config

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::connectors_config

=cut

use strict;
use warnings;
use pf::util;

use base 'pfconfig::namespaces::resource';
use pfconfig::namespaces::config::DnsConnectors;
use pfconfig::namespaces::config::Connector;
use pfconfig::namespaces::config::DomainsConnectors;

sub init {
    my ($self) = @_;

    $self->{domains} = $self->{cache}->get_cache("config::DomainsConnectors");
    $self->{dns} = $self->{cache}->get_cache("config::DnsConnectors");
    $self->{connector} = $self->{cache}->get_cache("config::Connector");

}

sub build {
    my ($self) = @_;

    my %ConfigDomains;
    my %ConfigConnector;

    foreach my $dns ( keys %{$self->{dns}} ) {
        foreach my $domain (split(',',$self->{dns}{$dns}{'domains'})) {
            my $dnsConfig;
            foreach my $key ( keys %{$self->{dns}{$dns}}) {
                next if ($key eq 'domains');
                $dnsConfig->{$key} = $self->{dns}{$dns}{$key};
            }
            $ConfigDomains{$domain}{$dns} = $dnsConfig;
        }
    }

    foreach my $connector ( keys %{$self->{connector}} ) {
        foreach my $key ( keys %{$self->{connector}{$connector}} ) {
             $ConfigConnector{$connector}{$key} = $self->{connector}{$connector}{$key};
        }
        foreach my $domain ( keys %{$self->{domains}} ) {
            if ($self->{domains}{$domain}{'connector'} eq $connector) {
                if (exists $ConfigDomains{$domain}) {
                    $ConfigConnector{$connector}{'domains'}{$domain} = $ConfigDomains{$domain};
                }
            }
        }
    }

    return \%ConfigConnector;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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


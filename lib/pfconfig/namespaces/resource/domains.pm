package pfconfig::namespaces::resource::domains;

=head1 NAME

pfconfig::namespaces::resource::domains

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::domains

This module change the domains configuration with env variable

=cut

use strict;
use warnings;
use pf::util;
use pf::util qw(isenabled);

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;

    # we depend on the switch configuration object (russian doll style)
    $self->{domains} = $self->{cache}->get_cache('config::Domain');
    $self->{config} = $self->{cache}->get_cache('config::Pf');
}

sub build {
    my ($self) = @_;
    my %ConfigDomains = %{$self->{domains}};
    my %Config = %{$self->{config}};
    while (my ($id, $cfg) = each(%ConfigDomains)){
        if (exists($cfg->{use_connector}) && isenabled($cfg->{use_connector})) {
            $ConfigDomains{$id}{ntlm_auth_host} = $Config{'services_host'}{'pfconnector_service_host'};
        }
    }

    return \%ConfigDomains;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

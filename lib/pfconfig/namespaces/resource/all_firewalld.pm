package pfconfig::namespaces::resource::all_firewalld;

=head1 NAME

pfconfig::namespaces::resource::all_firewalld

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::all_firewalld

=cut

use strict;
use warnings;
use pf::util;

use base 'pfconfig::namespaces::resource';
use pfconfig::namespaces::config::Firewalld_Config;
use pfconfig::namespaces::config::Firewalld_Services;
use pfconfig::namespaces::config::Firewalld_Zones;
use pfconfig::namespaces::config::Firewalld_Icmptypes;
use pfconfig::namespaces::config::Firewalld_Ipsets;
use pfconfig::namespaces::config::Firewalld_Policies;
use pfconfig::namespaces::config::Firewalld_Helpers;
use pfconfig::namespaces::config::Firewalld_Lockdown_Whitelist;

sub init {
    my ($self) = @_;
    my $firewalld_config = pfconfig::namespaces::config::Firewalld_Config->new( $self->{cache} );
    $firewalld_config->build();

    $self->{firewalld_config} = $self->{cache}->get_cache("config::Firewalld_Config");
    $self->{firewalld_services} = $self->{cache}->get_cache("config::Firewalld_Services");
    $self->{firewalld_zones} = $self->{cache}->get_cache("config::Firewalld_Zones");
    $self->{firewalld_icmptypes} = $self->{cache}->get_cache("config::Firewalld_Icmptypes");
    $self->{firewalld_ipsets} = $self->{cache}->get_cache("config::Firewalld_Ipsets");
    $self->{firewalld_policies} = $self->{cache}->get_cache("config::Firewalld_Policies");
    $self->{firewalld_helpers} = $self->{cache}->get_cache("config::Firewalld_Helpers");
    $self->{firewalld_lockdown_whitelist} = $self->{cache}->get_cache("config::Firewalld_Lockdown_Whitelist");
}

sub build {
    my ($self) = @_;

    my %ConfigFirewalld;
    $ConfigFirewalld{firewalld_config} = $self->{firewalld_config};
    $ConfigFirewalld{firewalld_services} = $self->{firewalld_services};
    $ConfigFirewalld{firewalld_zones}    = $self->{firewalld_zones};
    $ConfigFirewalld{firewalld_icmptypes}= $self->{firewalld_icmptypes};
    $ConfigFirewalld{firewalld_ipsets}   = $self->{firewalld_ipsets};
    $ConfigFirewalld{firewalld_policies} = $self->{firewalld_policies};
    $ConfigFirewalld{firewalld_helpers} = $self->{firewalld_helpers};
    $ConfigFirewalld{firewalld_lockdown_whitelist} = $self->{firewalld_lockdown_whitelist};

    return \%ConfigFirewalld;
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


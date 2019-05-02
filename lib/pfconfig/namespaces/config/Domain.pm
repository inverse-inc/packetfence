package pfconfig::namespaces::config::Domain;

=head1 NAME

pfconfig::namespaces::config::Domain

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Domain

This module creates the configuration hash associated to domain.conf

=cut


use strict;
use warnings;

use pfconfig::namespaces::config;
use Data::Dumper;
use pf::log;
use pf::file_paths qw($domain_config_file);
use Sys::Hostname;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $domain_config_file;
    $self->{child_resources} = [ 'resource::domain_dns_servers' ];
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{$self->{cfg}};

    # Inflate %h to the host machine name
    # This is done since Samba 4+ doesn't inflate it itself anymore
    while(my ($id, $cfg) = each(%tmp_cfg)){
        if(lc($cfg->{server_name}) =~ /%h/) {
            my $name = [split(/\./,hostname())]->[0];
            $cfg->{server_name} =~ s/%h/$name/;
        }
    }

    $self->{cfg} = \%tmp_cfg;

    return \%tmp_cfg;

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


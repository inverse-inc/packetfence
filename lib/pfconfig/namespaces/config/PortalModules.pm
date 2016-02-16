package pfconfig::namespaces::config::PortalModules;

=head1 NAME

pfconfig::namespaces::config::PortalModules

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::PortalModules

This module creates the configuration hash associated to portal_modules.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths;
use Config::IniFiles;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = "/usr/local/pf/conf/portal_modules.conf";
    
    my $defaults = Config::IniFiles->new( -file => "/usr/local/pf/conf/portal_modules.conf.defaults" );
    $self->{added_params}->{'-import'} = $defaults;
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{$self->{cfg}};

    foreach my $module_id (keys %tmp_cfg){
        $self->expand_list($tmp_cfg{$module_id}, qw(modules custom_fields));
    }

    return \%tmp_cfg;
}

=back

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:



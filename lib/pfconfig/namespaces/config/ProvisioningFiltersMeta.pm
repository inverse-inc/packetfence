package pfconfig::namespaces::config::ProvisioningFiltersMeta;

=head1 NAME

pfconfig::namespaces::config::ProvisioningFiltersMeta -

=head1 DESCRIPTION

pfconfig::namespaces::config::ProvisioningFiltersMeta

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw(
    $provisioning_filters_meta_config_file
    $provisioning_filters_meta_config_default_file
);
use pf::IniFiles;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $provisioning_filters_meta_config_file;

    my $defaults = pf::IniFiles->new( -file => $provisioning_filters_meta_config_default_file, -envsubst => 1 );
    $self->{added_params}->{'-import'} = $defaults;
    $self->{added_params}->{'-allowempty'} = 1;
}

sub build_child {
    my ($self) = @_;
    my %tmp_cfg = %{ $self->{cfg} };

    $self->cleanup_whitespaces( \%tmp_cfg );
    while (my ($k, $v) = each %tmp_cfg) {
        $v->{fields} = [map {"${k}.$_"} split(/\n/, $v->{fields} // '')];
    }

    return \%tmp_cfg;

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

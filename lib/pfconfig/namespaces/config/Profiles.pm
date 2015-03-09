package pfconfig::namespaces::config::Profiles;

=head1 NAME

pfconfig::namespaces::config::Profiles

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Profiles

This module creates the configuration hash associated to profiles.conf

=cut


use strict;
use warnings;

use pfconfig::namespaces::config;
use Data::Dumper;
use pfconfig::log;
use pf::file_paths;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $profiles_config_file;
    $self->{child_resources} = [
        'resource::Profile_Filters',
    ];
}

sub build_child {
    my ($self) = @_;

    my %Profiles_Config = %{$self->{cfg}};
    $self->cleanup_whitespaces(\%Profiles_Config);

    foreach my $key (%Profiles_Config){
        $self->expand_list($Profiles_Config{$key}, qw(sources filter locale mandatory_fields allowed_devices provisioners));
    }

    $self->{cfg} = \%Profiles_Config;

    return \%Profiles_Config;

}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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


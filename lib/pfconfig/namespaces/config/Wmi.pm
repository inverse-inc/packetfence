package pfconfig::namespaces::config::Wmi;

=head1 NAME

pfconfig::namespaces::config::Wmi

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Wmi

This module creates the configuration hash associated to wmi.conf

=cut


use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::log;
use pf::file_paths qw($wmi_config_file);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $wmi_config_file;
    $self->{expandable_params} = qw(actions);
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{$self->{cfg}};

    foreach my $key ( keys %tmp_cfg){
        $self->cleanup_after_read($key, $tmp_cfg{$key});
        $self->cleanup_whitespaces( \%tmp_cfg );
    }

    return \%tmp_cfg;

}

sub cleanup_after_read {
    my ($self, $id, $item) = @_;
    $self->expand_list($item, $self->{expandable_params});
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


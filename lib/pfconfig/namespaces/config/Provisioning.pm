package pfconfig::namespaces::config::Provisioning;

=head1 NAME

pfconfig::namespaces::config::Provisioning

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Provisioning

This module creates the configuration hash associated to provisioning.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw($provisioning_config_file);
use List::MoreUtils qw(uniq);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $provisioning_config_file;
    $self->{child_resources} = ['resource::ProvisioningReverseLookup', 'resource::passthroughs', 'resource::RolesReverseLookup'];
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{ $self->{cfg} };
    my %reverseLookup;
    $self->{roleReverseLookup} = {};

    while ( my ($key, $provisioner) = each %tmp_cfg) {
        $self->cleanup_after_read($key, $provisioner);
        $self->updateRoleReverseLookup($key, $provisioner, 'provisioning', qw(category role_to_apply));
        foreach my $field (qw(pki_provider)) {
            my $values = $provisioner->{$field};
            if (ref ($values) eq '') {
                next if !defined $values || $values eq '';

                $values = [$values];
            }

            for my $val (@$values) {
                push @{$reverseLookup{$field}{$val}}, $key;
            }
        }
        if (exists $provisioner->{security_type}) {
            my $value = $provisioner->{security_type};
            if (defined $value && $value eq 'WPA2') {
                $provisioner->{security_type} = 'WPA';
            }
        }
    }
    $self->{reverseLookup} = \%reverseLookup;

    return \%tmp_cfg;

}

sub cleanup_after_read {
    my ( $self, $id, $data ) = @_;
    $self->expand_list( $data, qw(category oses) );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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


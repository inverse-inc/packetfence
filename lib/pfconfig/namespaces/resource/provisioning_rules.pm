package pfconfig::namespaces::resource::provisioning_rules;

=head1 NAME

pfconfig::namespaces::resource::provisioning_rules -

=head1 DESCRIPTION

pfconfig::namespaces::resource::provisioning_rules

=cut

use strict;
use warnings;
use pfconfig::namespaces::config;
use pfconfig::namespaces::config::ProvisioningFilters;
use base 'pfconfig::namespaces::resource';

sub build {
    my ($self) = @_;
    my $config = pfconfig::namespaces::config::ProvisioningFilters->new($self->{cache});
    my $filters = $config->build;
    my %data;
    my @lookup;
    while ( my ( $k, $v ) = each %$filters ) {
        my $type = $v->{type};
        next if !defined $type;
        if ( $type eq 'lookup' ) {
            push @lookup, $k;
        } else {
            push @{ $data{$type} }, $k;
        }
    }

    for my $v (values %data) {
        push @$v, @lookup;
    }

    return \%data;
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

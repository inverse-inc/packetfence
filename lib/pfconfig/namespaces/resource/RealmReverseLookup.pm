package pfconfig::namespaces::resource::RealmReverseLookup;

=head1 NAME

pfconfig::namespaces::resource::RealmReverseLookup -

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::RealmReverseLookup

=cut

use strict;
use warnings;
use pfconfig::namespaces::config;
use pfconfig::namespaces::config::Realm;
use pf::factory::condition::profile;

use base 'pfconfig::namespaces::resource';

sub build {
    my ($self) = @_;

    my $config = pfconfig::namespaces::config::Realm->new( $self->{cache} );
    my %Realms_Config = %{ $config->build };

    return $config->{reverseLookup};
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


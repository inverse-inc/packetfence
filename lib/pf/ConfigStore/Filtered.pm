package pf::ConfigStore::Filtered;
=head1 NAME

pf::ConfigStore::Filtered

=cut

=head1 DESCRIPTION

pf::ConfigStore::Filtered
A role to filter out specific sections of a ConfigStore based on an arbitrary filter subroutine

=cut

use Moo::Role;
use namespace::autoclean;
use List::MoreUtils qw(any);

=head2 _Sections

Override _Sections and apply filter on them

=cut

sub _Sections {
    my ($self) = @_;
    return grep { $self->filter($_) } $self->cachedConfig->Sections();
}

=head2 _hasId

Is the ID present in the filtered sections

=cut

sub _hasId {
    my ($self, $id) = @_;
    return any { $_ eq $id } $self->_Sections();
}

=head2 hasId

Override hasId to take into consideration the filtered sections

=cut

sub hasId {
    my ($self, $id ) = @_;
    my $config = $self->cachedConfig;
    $id = $self->_formatSectionName($id);
    return $config->SectionExists($id) && $self->_hasId($id);
}

=back

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


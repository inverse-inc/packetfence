package ConfigStore::HierarchyTest;

=head1 NAME

ConfigStore::HierarchyTest

=cut

=head1 DESCRIPTION

Class used to test the Hierarchy role of the Configstore

=cut

use Moo;
use pf::ConfigStore;
use pf::ConfigStore::Hierarchy;

extends qw(pf::ConfigStore);
with qw(pf::ConfigStore::Hierarchy);

sub default_section { undef }

sub topLevelGroup { "group default" }

sub _formatGroup {
    return "group ".$_[1];
}

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


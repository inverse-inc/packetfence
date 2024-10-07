package pf::ConfigStore::All;

=head1 NAME

pf::ConfigStore::All -

=head1 DESCRIPTION

pf::ConfigStore::All

=cut

use strict;
use warnings;
use Role::Tiny qw();

use Module::Pluggable
  'search_path' => [qw(pf::ConfigStore)],
  'sub_name'    => '_all_stores',
  'require'     => 1,
  'inner'       => 0,
  ;

our @STORES;

sub all_stores {
    if (!@STORES) {
        my @tmp_stores = __PACKAGE__->_all_stores();
        @STORES = grep { $_ ne __PACKAGE__ && !Role::Tiny->is_role($_) && !$_->does('pf::ConfigStore::Group') && !$_->does('pf::ConfigStore::Filtered') } @tmp_stores;
    }

    return [@STORES];
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

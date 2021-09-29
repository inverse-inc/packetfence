package pfconfig::namespaces::config::OrderedRealmAll;

=head1 NAME

pfconfig::namespaces::config::OrderedRealmAll

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::OrderedRealmAll

This module creates the configuration array associated to realm.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw(
  $realm_default_config_file
  $realm_config_file
);

use base 'pfconfig::namespaces::config::OrderedRealm';

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    delete $self->{_scoped_by_tenant_id};
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

package pfappserver::Base::Form::Role::InternalSource;

=head1 NAME

pfappserver::Base::Form::Role::InternalSource - Role for Local Accounts

=cut

=head1 DESCRIPTION

pfappserver::Base::Form::Role::InternalSource

=cut

use strict;
use warnings;
use namespace::autoclean;
use HTML::FormHandler::Moose::Role;
use pf::config qw(%ConfigRealm);
with 'pfappserver::Base::Form::Role::Help';

has_field 'realms' => (
    type           => 'Select',
    multiple       => 1,
    label          => 'Associated Realms',
    options_method => \&options_realm,
    element_class  => ['chzn-deselect', 'input-xxlarge'],
    element_attr   => { 'data-placeholder' => 'Click to add a realm' },
    tags           => {
        after_element => \&help,
        help          => 'Realms that will be associated with this source (For the Portal/Admin GUI/RADIUS post-auth, not for FreeRADIUS proxy)'
    },
    default => '',
);

has_block internal_sources => (
    render_list => [qw(realms)],
);

=head2 options_realm

retrive the realms

=cut

sub options_realm {
    my ($self) = @_;
    my @roles = map { $_ => $_ } sort keys %ConfigRealm;
    return @roles;
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


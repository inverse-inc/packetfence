package pfappserver::Base::Form::Role::SourcesAssociated;

=head1 NAME

pfappserver::Base::Form::Role::SourcesAssociated 

=cut

=head1 DESCRIPTION

pfappserver::Base::Form::Role::SourcesAssociated

=cut

use strict;
use warnings;
use namespace::autoclean;
use HTML::FormHandler::Moose::Role;
use pf::authentication;
with 'pfappserver::Base::Form::Role::Help';

has_field 'sources' => (
    type           => 'Select',
    multiple       => 1,
    label          => 'Associated Source',
    options_method => \&options_sources,
    element_class  => ['chzn-deselect', 'input-xxlarge'],
    element_attr   => { 'data-placeholder' => 'Click to add a source' },
    tags           => {
        after_element => \&help,
        help          => 'Sources that will be associated with this source (For the Sponsor)'
    },
    default => '',
);

has_block associated_sources => (
    render_list => [qw(sources)],
);

=head2 options_sources

Returns the list of sources to be displayed

=cut

sub options_sources {
    return map { { value => $_->id, label => $_->id, attributes => { 'data-source-class' => $_->class  } } } grep { $_->{'type'} eq "AD" or $_->{'type'} eq "LDAP" or $_->{'type'} eq "SQL" } @{getInternalAuthenticationSources()};
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

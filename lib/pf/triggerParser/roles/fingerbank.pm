package pf::triggerParser::roles::fingerbank;
=head1 NAME

pf::triggerParser::roles::fingerbank add documentation

=cut

=head1 DESCRIPTION

pf::triggerParser::roles::fingerbank

=cut

use strict;
use warnings;
use Moo::Role;

has 'fingerbankModel' => ( required => 1, is => 'rw' );

has 'lookupField' => ( required => 1, is => 'rw', default => sub { "value" } );

=head2 search

Lookup

=cut

sub search {
    my ($self,$query) = @_;
    my $lookup = $self->lookupField;
    my ($status,$result) = $self->fingerbankModel->search([{ $lookup => { -like => "%$query%" } }]);
    my @items;
    foreach my $resultset ( @$result) {
        while(my $row = $resultset->next) {
            push @items, { display => $row->$lookup, value => $row->id };
        }
    }
    return \@items;
}

 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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


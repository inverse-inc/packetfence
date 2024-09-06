package pf::UnifiedApi::Search::Builder::Users;

=head1 NAME

pf::UnifiedApi::Search::Builder::Users -

=head1 DESCRIPTION

pf::UnifiedApi::Search::Builder::Users

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::UnifiedApi::Search::Builder);
use pf::dal::password;


our @IP4LOG_JOIN =  (
    '=>{person.pid=password.pid}',
    qw(password =>{node_category.category_id=password.category} node_category)
);

our %ALLOWED_JOIN_FIELDS = (
    'category_name' => {
        join_spec     => \@IP4LOG_JOIN,
        column_spec   => 'node_category.name|category_name',
        namespace     => 'person',
    },
);

sub allowed_join_fields {
    \%ALLOWED_JOIN_FIELDS
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

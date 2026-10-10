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


our @PASSWORD_JOIN =  (
    '=>{person.pid=password.pid}',
    qw(password =>{node_category.category_id=password.category} node_category)
);

our @PASSWORD_FIELDS = qw(
    valid_from
    expiration
    access_duration
    access_level
    sponsor
    unregdate
    login_remaining
);

our %ALLOWED_JOIN_FIELDS = (
    'category_name' => {
        join_spec     => \@PASSWORD_JOIN,
        column_spec   => 'node_category.name|category_name',
        namespace     => 'password',
    },
    'account_type' => {
        join_spec     => \@PASSWORD_JOIN,
        column_spec   => \"IF(`password`.`pid` IS NULL, 'remote', 'local') AS `account_type`",
        namespace     => 'password',
        rewrite_query => \&rewrite_account_type_query,
    },
    (
        map {;
            "password.$_" => {
                join_spec   => \@PASSWORD_JOIN,
                column_spec => \"`password`.`$_` AS `password.$_`",
                namespace   => 'password',
            }
        } @PASSWORD_FIELDS
    ),
);

sub allowed_join_fields {
    \%ALLOWED_JOIN_FIELDS
}

=head2 rewrite_account_type_query

A user is local when it has a local account (an entry in the password table), remote otherwise

=cut

sub rewrite_account_type_query {
    my ($self, $s, $q) = @_;
    my $op = $q->{op};
    if ($op ne 'equals' && $op ne 'not_equals') {
        return (422, { message => "$op is not valid for the account_type field" });
    }

    my $value = $q->{value};
    if (!defined $value || ($value ne 'local' && $value ne 'remote')) {
        return (422, { message => "value of " . ($value // "(null)") . " is not valid for the account_type field" });
    }

    my $is_local = ($value eq 'local') == ($op eq 'equals');
    return (200, \[$is_local ? "`password`.`pid` IS NOT NULL" : "`password`.`pid` IS NULL"]);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

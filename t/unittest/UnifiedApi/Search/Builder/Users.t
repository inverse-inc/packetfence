#!/usr/bin/perl

=head1 NAME

Users

=head1 DESCRIPTION

unit test for Users

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 15;

#This test will running last
use Test::NoWarnings;
use pf::UnifiedApi::Search::Builder::Users;
use pf::dal::person;
use pf::dal::password;

my $dal = "pf::dal::person";
my $sb = pf::UnifiedApi::Search::Builder::Users->new();
my @PASSWORD_JOIN = @pf::UnifiedApi::Search::Builder::Users::PASSWORD_JOIN;

sub search_info {
    my ($fields, $query) = @_;
    return {
        dal    => $dal,
        fields => $fields,
        (defined $query ? (query => $query) : ()),
    };
}

sub from_of {
    my ($status, $args) = $sb->make_search_args(@_);
    return [ $status, $args->{-from} ];
}

sub account_type_where {
    my ($op, $value) = @_;
    return [ $sb->make_where(search_info([qw(pid)], { op => $op, field => 'account_type', value => $value })) ];
}

is_deeply(
    [ sort grep { /^password\./ } keys %{ $sb->allowed_join_fields } ],
    [ map { "password.$_" } sort qw(valid_from expiration access_duration access_level sponsor unregdate login_remaining) ],
    'Only the listed local account fields are exposed: not the password, nor the other columns of the password table'
);

{
    my $search_info = search_info([qw(pid category_name password.sponsor account_type)]);
    is_deeply(
        [ $sb->make_columns($search_info) ],
        [
            200,
            [
                'person.pid',
                'node_category.name|category_name',
                \"`password`.`sponsor` AS `password.sponsor`",
                \"IF(`password`.`pid` IS NULL, 'remote', 'local') AS `account_type`",
            ],
        ],
        'Return the columns'
    );

    # make_columns rewrites the fields in place: use a fresh search_info
    is_deeply(
        from_of(search_info([qw(pid category_name password.sponsor account_type)])),
        [ 200, [ -join => 'person', @PASSWORD_JOIN ] ],
        'category_name, password.* and account_type join the password table once'
    );
}


is_deeply(
    from_of(search_info([qw(pid)], { op => 'equals', field => 'account_type', value => 'local' })),
    [ 200, [ -join => 'person', @PASSWORD_JOIN ] ],
    'Searching on account_type joins the password table'
);

is_deeply(
    from_of(search_info([qw(pid)])),
    [ 200, [ 'person' ] ],
    'No join without a password field'
);

is_deeply(account_type_where('equals', 'local'), [ 200, { -nest => \["`password`.`pid` IS NOT NULL"] } ], 'account_type equals local');
is_deeply(account_type_where('equals', 'remote'), [ 200, { -nest => \["`password`.`pid` IS NULL"] } ], 'account_type equals remote');
is_deeply(account_type_where('not_equals', 'local'), [ 200, { -nest => \["`password`.`pid` IS NULL"] } ], 'account_type not_equals local');
is_deeply(account_type_where('not_equals', 'remote'), [ 200, { -nest => \["`password`.`pid` IS NOT NULL"] } ], 'account_type not_equals remote');

{
    my ($status, $error) = @{ account_type_where('contains', 'loc') };
    is($status, 422, 'account_type contains is refused');
    like($error->{message} // join(" ", map { $_->{message} // '' } @{$error->{errors} // []}), qr/contains is not valid for the account_type field/, 'with the reason');
}

{
    my ($status, $error) = @{ account_type_where('equals', 'foo') };
    is($status, 422, 'account_type with an unknown value is refused');
    like($error->{message} // join(" ", map { $_->{message} // '' } @{$error->{errors} // []}), qr/value of foo is not valid for the account_type field/, 'with the reason');
}

is(($sb->make_columns(search_info([qw(pid password.password)])))[0], 422, 'password.password is refused as a column');

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

package pfappserver::Base::Model::Search;
=head1 NAME

pfappserver::Base::Model::Search add documentation

=cut

=head1 DESCRIPTION

Search

=cut

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use pf::util;
use pf::SearchBuilder;
extends 'pfappserver::Base::Model';

my %OP_MAP = (
    equal       => '=',
    not_equal   => '<>',
    not_like    => 'NOT LIKE',
    like        => 'LIKE',
    ends_with   => 'LIKE',
    starts_with => 'LIKE',
    in          => 'IN',
    not_in      => 'NOT IN',
    is_null     => 'IS NULL',
    is_not_null => 'IS NOT NULL',
);

=head2 Methods

=over

=item process_query

transform search queries from search form
To create where arguments for the sql builder

=cut

sub process_query {
    my ($self, $query) = (@_);
    $self->_pre_process_query($query);
    my $op = $query->{op};
    die "$op is not a supported search operation"
        unless exists $OP_MAP{$op};
    my $sql_op = $OP_MAP{$op};
    my @escape;
    my @where_args = ($query->{name}, $sql_op);
    my $value = $query->{value};
    return unless defined $value || $sql_op eq 'IS NULL' || $sql_op eq 'IS NOT NULL';
    my @values;
    if($sql_op eq 'LIKE' || $sql_op eq 'NOT LIKE') {
        #escaping the % and _ charcaters
        if($value =~ s/([%_])/\\$1/g) {
           @escape = ("\\");
        }
        if($op eq 'like' || $op eq 'not_like') {
            $value = "\%$value\%";
        } elsif ($op eq 'starts_with') {
            $value = "$value\%";
        } elsif ($op eq 'ends_with') {
            $value = "\%$value";
        }
    }
    push @values, $value if defined $value;
    push @where_args, @values, @escape;
    return \@where_args;
}

sub _pre_process_query {
    my ($self, $query) = @_;
    if( $query->{name} eq 'mac' && $query->{op} eq 'equal' ) {
        my $value = $query->{value};
        $value =~ s/^ *//;
        $value =~ s/ *$//;
        if(valid_mac($value)) {
            $query->{value} = clean_mac($value);
        }
    }
}

=item add_limit

add limits to the sql builder

=cut

sub add_limit {
    my ($self, $builder, $params) = @_;
    my $page_num = $params->{page_num} || 1;
    my $limit  = $params->{per_page} || 25;
    my $offset = (( $page_num - 1 ) * $limit);
    $builder->limit($limit, $offset);
}

=item add_joins

add joins to the sql builder

=cut

sub add_joins {}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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


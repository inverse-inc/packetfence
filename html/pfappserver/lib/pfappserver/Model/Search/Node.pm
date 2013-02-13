package pfappserver::Model::Search::Node;
=head1 NAME

pfappserver::Model::Search::Node add documentation

=cut

=head1 DESCRIPTION

Node

=cut

use strict;
use warnings;
use Moose;
use pfappserver::Base::Model::Search;
use pf::SearchBuilder;
use pf::node qw(node_custom_search);

extends 'pfappserver::Base::Model::Search';

sub search {
    my ($self,$params) = @_;
    my %results;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $builder = new pf::SearchBuilder;
    $builder
        ->select(\'*')
        ->from('node');
    my @searches = map {$self->process_query($_)} @{$params->{searches}};
    my ($start,$end,$all_or_any,$page_num,$per_page) = @{$params}{qw(start end all_or_any)};
    $self->add_joins($builder,$params);
    $self->add_limit($builder,$params);
    if($start && $end) {
    }
    if ($all_or_any eq 'any' ) {
        $all_or_any = 'or';
    } else {
        $all_or_any = 'and';
    }
    if(@searches) {
        $builder->where('(');
        $builder->where($all_or_any)->where(@$_) for @searches;
        $builder->where(')');
    }
    my $sql = $builder->sql;
    $results{items} = [node_custom_search($sql)];
    return %results;
}

my %JOIN_MAP = (
    violation => 1
);

sub add_joins {
    my ($self,$builder,$params) = @_;
}

sub add_limit {
    my ($self,$builder,$params) = @_;
    my $page_num = $params->{page_num} || 1;
    my $limit  = $params->{per_page} || 25;
    my $offset = (( $page_num - 1 ) * $limit );
    $builder->limit($limit,$offset);
}

__PACKAGE__->meta->make_immutable;

=back

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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


package pfappserver::Model::Config::Wrix;

=head1 NAME

pfappserver::Model::Config::Wrix add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Wrix;

=cut

use Moose;
use namespace::autoclean;
use pf::RoseDB::Wrix::Manager;
use HTTP::Status qw(:constants is_error is_success);
use pf::log;
use pf::util qw(calc_page_count);
our %OP_MAP = (
    equal       => '=',
    not_equal   => '<>',
    not_like    => 'NOT LIKE',
    like        => 'LIKE',
    ends_with   => 'LIKE',
    starts_with => 'LIKE',
    in          => 'IN',
    not_in      => 'NOT IN',
);


extends 'pfappserver::Base::Model::DB';

has '+managerClassName' => (default => 'pf::RoseDB::Wrix::Manager');

=head1 METHODS

=head2 remove

Delete an existing item

=cut

sub remove {
    my ($self,$id) = @_;
    if($id eq 'all') {
        return ($STATUS::INTERNAL_SERVER_ERROR, "Cannot delete this item");
    }
    return $self->SUPER::remove($id);
}

sub search {
    my ($self,$parameters) = @_;
    my $pageNum = $parameters->{page_num} // 1;
    my $perPage = $parameters->{per_page} // 25;
    my $manager = $self->manager;
    my $logger = get_logger();
    my $all_or_any = $parameters->{all_or_any} || 'and';
    $all_or_any = 'or' if $all_or_any eq 'any';
    $all_or_any = 'and' if $all_or_any eq 'all';
    my @queries = map { $self->build_query($_) } @{$parameters->{searches}};
    my $count = $manager->get_objects_count(
        query => [$all_or_any => \@queries]
    );
    my $items = $manager->get_objects(
        page     => $pageNum,
        per_page => $perPage,
        query => [$all_or_any => \@queries]
    );
    my $pageCount = calc_page_count($count, $perPage);
    return (HTTP_OK, {
        #%$parameters,
        page_num => $pageNum,
        per_page => $perPage,
        items   => $items,
        page_count => $pageCount,
    });

}
sub build_query {
    my ($self,$search) = @_;
    my $query;
    my ($name,$op,$value) = @{$search}{qw(name op value)};
    my $sql_op = $OP_MAP{$op};
    if($sql_op eq 'LIKE' || $sql_op eq 'NOT LIKE') {
        #escaping the % and _ charcaters
        $value =~ s/([%_])/\\$1/g;
        if($op eq 'like' || $op eq 'not_like') {
            $value = "\%$value\%";
        } elsif ($op eq 'starts_with') {
            $value = "$value\%";
        } elsif ($op eq 'ends_with') {
            $value = "\%$value";
        }
    }
    return ($name => {$sql_op => $value});
}



__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};


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


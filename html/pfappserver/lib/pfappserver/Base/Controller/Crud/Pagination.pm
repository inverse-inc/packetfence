package pfappserver::Base::Controller::Crud::Pagination;

=head1 NAME

pfappserver::Base::Controller::Crud::Config::Pagination add documentation

=cut

=head1 DESCRIPTION

PortalProfile

=cut

use strict;
use warnings;
use HTTP::Status qw(:constants is_error is_success);
use MooseX::MethodAttributes::Role;
use namespace::autoclean;
use Log::Log4perl qw(get_logger);
use HTML::FormHandler::Params;

=head2 Methods

=head2 list

=cut

sub list :Local :Args {
    my ( $self, $c , $pageNum, $perPage) = @_;
    $pageNum = 1 unless $pageNum;
    $perPage = 25 unless $perPage;
    my $model = $self->getModel($c);
    my ($status,$items,$result);
    ($status,$result) = $model->readAll($pageNum, $perPage);
    if(is_success($status) ) {
        $items = $result;
        ($status,$result) = $model->countAll;
    }
    if (is_error($status)) {
        $c->res->status($status);
        $c->error($c->loc($result));
    } else {
        my $itemsKey = $model->itemsKey;
        my $pageCount = int( $result / $perPage) + 1;
        $c->stash(
            $itemsKey => $items,
            itemsKey  => $itemsKey,
            pageNum   => $pageNum,
            perPage   => $perPage,
            pageCount => $pageCount,
        )
    }
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

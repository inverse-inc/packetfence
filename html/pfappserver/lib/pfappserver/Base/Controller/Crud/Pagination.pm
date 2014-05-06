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

1;

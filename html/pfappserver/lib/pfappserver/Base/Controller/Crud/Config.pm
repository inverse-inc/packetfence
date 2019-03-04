package pfappserver::Base::Controller::Crud::Config;

=head1 NAME

pfappserver::Base::Controller::Crud::Config add documentation

=cut

=head1 DESCRIPTION

ConnectionProfile

=cut

use strict;
use warnings;
use HTTP::Status qw(:constants is_error is_success);
use MooseX::MethodAttributes::Role;
use namespace::autoclean;
use pf::log;
use HTML::FormHandler::Params;

with 'pfappserver::Base::Controller::Crud';

=head2 Methods

=over

=cut

sub sort_items : Local: Args(0) {
    my ($self,$c) = @_;
    my $model = $self->getModel($c);
    my $params_handler =  HTML::FormHandler::Params->new;
    my $items = $params_handler->expand_hash($c->request->params);
    my $itemsKey = $model->itemsKey;
    my ($status,$status_msg) = $model->sortItems($items->{$itemsKey});
    $self->audit_current_action($c, status => $status);
    $c->stash(
        current_view => 'JSON',
        status_msg => $status_msg,
    );
    $c->response->status($status);
}

after [qw(update remove rename_item sort_items)] => sub {
    my ($self,$c) = @_;
    if(is_success($c->response->status) ) {
        $self->_commitChanges($c);
    }
};

after create => sub {
    my ($self,$c) = @_;
    if(is_success($c->response->status) && $c->request->method eq 'POST' ) {
        $self->_commitChanges($c);
    }
};


sub _commitChanges {
    my ($self,$c) = @_;
    my $logger = get_logger();
    my $model = $self->getModel($c);
    my ($status,$status_msg) = $model->commit();
    if(is_error($status)) {
        $c->stash(
            current_view => 'JSON',
            status_msg => $status_msg,
        );
    }
    $logger->info($status_msg);
    $c->response->status($status);
}



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


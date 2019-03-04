package pfappserver::PacketFence::Controller::Config::Wrix;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Wrix - Catalyst Controller

=head1 DESCRIPTION


=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use DateTime;
use File::Temp qw/tempfile :seekable/;

use pf::util qw(sort_ip);

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::DB';
    with 'pfappserver::Base::Controller::Crud::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object dispatcher from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/wrix', CaptureArgs => 1 },
        view   => { AdminRole => 'WRIX_READ' },
        list   => { AdminRole => 'WRIX_READ' },
        create => { AdminRole => 'WRIX_CREATE' },
        clone  => { AdminRole => 'WRIX_CREATE' },
        update => { AdminRole => 'WRIX_UPDATE' },
        remove => { AdminRole => 'WRIX_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::Wrix",form => "Config::Wrix" },
        search => { model => "Config::Wrix", form => 'AdvancedSearch'}
    },
);

=head1 METHODS

=head2 index

Usage: /config/wrix/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->forward('list');
}

sub export :Local {
    my ($self, $c) = @_;
    my $model = $self->getModel($c);
    my $fh = File::Temp->new(UNLINK => 1);
    $c->log->debug( sub { "tempfile for exporting is " . $fh->filename } );
    $model->manager->exportCsv($fh);
    # Flushing all the changes
    $fh->flush();
    # Moving the file handle position to the begining of the file
    $fh->seek(0,SEEK_SET);
    $c->response->header('Content-Type' => "text/csv");
    $c->response->header('Content-Disposition' => "attachment; filename=export.csv");
    $c->response->body($fh);
}

sub search :Local :Args() {
    my ($self, $c) = @_;
    if ($c->request->method ne 'POST') {
        $c->detach('list');
    }
    my $form = $self->getForm($c);
    my ($status_msg, $result);
    my $status = HTTP_OK;
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $c->stash({
            current_view => 'JSON',
            status_msg => $form->field_errors,
        });
        $status = HTTP_BAD_REQUEST;
    } else {
        my $model = $self->getModel($c);
        my $query = $form->value;
        if (grep { defined $_->{'value'} } @{$query->{'searches'}}) {
            # At least one search criteria has a value
            ($status, $result) = $model->search($query);
            if (is_success($status)) {
                $c->stash(form => $form);
                $c->stash($result);
            }
        }
        else {
            $c->forward('list');
        }
    }
    $c->response->status($status);
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

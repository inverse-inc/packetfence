package pfappserver::Controller::Profile;
=head1 NAME

pfappserver::Controller::Profile

=cut

=head1 DESCRIPTION

User

=cut

use strict;
use warnings;
use Moose;
use HTTP::Status qw(:constants is_error is_success);

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud';
}


=head2 Methods

=over

=item begin

Setting the current form instance and model

=cut

sub begin :Private {
    my ( $self, $c ) = @_;
    pf::config::cached::ReloadConfigs();
    $c->stash->{current_model_instance} = $c->model("Config::Profile")->new;
    $c->stash->{current_form_instance} = $c->form("Portal::Profile")->new(ctx=>$c);
}


=item object

=cut

sub object :Chained('/') :PathPart('profile') : CaptureArgs(1) {
    my ($self,$c,$id) = @_;
    $self->_setup_object($c,$id);
    $c->stash->{item}{id} = $id;
}

=item update

=cut

after 'update' => sub {
    my ( $self, $c ) = @_;
    my $model = $self->getModel();
    $model->rewriteConfig();
};


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


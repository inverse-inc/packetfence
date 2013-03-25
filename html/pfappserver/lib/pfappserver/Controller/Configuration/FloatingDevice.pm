package pfappserver::Controller::Configuration::FloatingDevice;

=head1 NAME

pfappserver::Controller::Configuration::FloatingDevice - Catalyst Controller

=head1 DESCRIPTION

Controller for floating device management.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pfappserver::Form::Config::Switch;

BEGIN {
    extends 'pfappserver::Base::Controller::Base';
    with 'pfappserver::Base::Controller::Crud::Config';
}

=head2 Methods

=over

=item begin

Setting the current form instance and model

=cut

sub begin :Private {
    my ( $self, $c ) = @_;
}

=item object

/configuration/floatingdevice/*

=cut

sub object :Chained('/') :PathPart('configuration/floatingdevice') :CaptureArgs(1) {
    my ($self,$c,$id) = @_;
    $self->getModel($c)->readConfig();
    $self->_setup_object($c,$id);
}


=item index

Usage: /configuration/floatingdevice/

=cut



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

__PACKAGE__->meta->make_immutable;

1;

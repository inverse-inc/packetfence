package pfappserver::PacketFence::Controller::Config::Fingerbank::User_Agent;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Fingerbank::User_Agent

=head1 DESCRIPTION

Controller for managing the fingerbank User_Agent data

=cut

use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Fingerbank' => { -excludes => 'index' };
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object and scope actions from
        __PACKAGE__->action_defaults,
        scope  => { Chained => '/', PathPart => 'config/fingerbank/user_agent', CaptureArgs => 1 },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => __PACKAGE__->get_model_name , form => __PACKAGE__->get_form_name },
    },
);

=head1 index

Setup the scope and forwards

Overwrite L<pfappserver::Base::Controller::Crud::Fingerbank::index> because we don't want "upstream" scope with Combinations

=cut

sub index {
    my ( $self, $c ) = @_;

    $c->stash(
        scope                   => 'Local',
        fingerbank_configured   => fingerbank::Config::is_api_key_configured,
        action                  => 'list',
    );
    $c->forward('list');
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

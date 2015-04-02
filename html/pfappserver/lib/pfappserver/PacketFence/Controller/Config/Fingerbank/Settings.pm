package pfappserver::PacketFence::Controller::Config::Fingerbank::Settings;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Fingerbank::Settings

=head1 DESCRIPTION

Basic interaction with Fingerbank database.

Customizations can be made using L<pfappserver::Controller::Config::Fingerbank::Settings>

=cut

use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use fingerbank::Config;

use HTTP::Status qw(:constants is_error is_success);

BEGIN { extends 'pfappserver::Base::Controller'; }

=head2 check_for_api_key

=cut

sub check_for_api_key :Private {
    my ( $self, $c ) = @_;
    my $logger = pf::log::get_logger;

    if ( !fingerbank::Config::is_api_key_configured ) {
        $logger->warn("Fingerbank API key is not configured. Running with limited features");
        my $status_msg = "It looks like Fingerbank API key is not configured. You may have forgot the onboard process. To fully beneficiate of Fingerbank, please proceed here: https://fingerbank.inverse.ca/onboard";
        $c->go('onboard');
    }
}

sub onboard :Local :Args(0) :AdminRole('FINGERBANK_UPDATE') {
    my ( $self, $c ) = @_;
    my $logger = pf::log::get_logger;

    $c->forward('index') if ( fingerbank::Config::is_api_key_configured );

    my ( $status, $status_msg ) = HTTP_OK;
    my $form = $c->form("Config::Fingerbank::Onboard");

    if ( $c->request->method eq 'POST' ) {
        $form->process(params => $c->req->params);
        if ( $form->has_errors ) {
            $status = HTTP_PRECONDITION_FAILED;
            $status_msg = $form->field_errors;
        } else {
            my %params = ();
            $params{'upstream'}{'api_key'} = $c->req->params->{'api_key'};
            ( $status, $status_msg ) = fingerbank::Config::write_config(\%params);
            $c->req->method('GET'); # We need to change the request method since there's a filter  on it in the index part.
            $c->go('index');
        }
    }

    else {
        $form->process;
        $c->stash->{form} = $form;
    }

    if ( is_error($status) ) {
        $c->stash(
            current_view => 'JSON',
            status_msg => $status_msg
        );
    }

    $c->response->status($status);
}

=head2 index

=cut

sub index :Path :Args(0) :AdminRole('FINGERBANK_READ') {
    my ( $self, $c ) = @_;
    my $logger = pf::log::get_logger;

    $c->forward('check_for_api_key');

    my ( $status, $status_msg ) = HTTP_OK;
    my $form = $c->form("Config::Fingerbank::Settings");

    if ( $c->request->method eq 'POST' ) {
        $form->process(params => $c->req->params);
        if ( $form->has_errors ) {
            $status = HTTP_PRECONDITION_FAILED;
            $status_msg = $form->field_errors;
        } else {
            my $params = $form->value;

            # TODO: Ugly hack to handle the fact that unchecked checkboxes are not being returned as a param by HTTP and needs
            # to be set as 'disabled'
            ( !$params->{'upstream'}{'interrogate'} ) ? $params->{'upstream'}{'interrogate'} = 'disabled':();
            ( !$params->{'query'}{'record_unmatched'} ) ? $params->{'query'}{'record_unmatched'} = 'disabled':();

            ( $status, $status_msg ) = fingerbank::Config::write_config($params);
        }
    }

    else {
        my $config = fingerbank::Config::get_config;
        $form->process(init_object => $config);
        $c->stash->{form} = $form;
    }

    if ( is_error($status) ) {
        $c->stash(
            current_view => 'JSON',
            status_msg => $status_msg
        );
    }

    $c->response->status($status);
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

__PACKAGE__->meta->make_immutable;

1;

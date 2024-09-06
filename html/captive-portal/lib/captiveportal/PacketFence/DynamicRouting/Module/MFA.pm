package captiveportal::PacketFence::DynamicRouting::Module::MFA;

=head1 NAME

captiveportal::DynamicRouting::Module::MFA

=head1 DESCRIPTION

MFA module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';

use pf::constants;
use pf::log;
use pf::util;
use pf::mfa;
use pf::node;
use pf::factory::mfa;

has 'skipable' => (is => 'rw', default => sub {'disabled'});

has 'request_fields' => (is => 'rw', traits => ['Hash'], builder => '_build_request_fields', lazy => 1);

=head2 allowed_urls

The allowed URLs for the module

=cut

sub allowed_urls {[
    '/mfa',
]}

=head2 _build_request_fields

Builder for the request fields

=cut

sub _build_request_fields {
    my ($self) = @_;
    return $self->app->hashed_params()->{fields} || {};
}

=head2 get_mfa

Get the mfa from the session or the connection profile

=cut

sub get_mfa {
    my ($self) = @_;
    if (defined $self->app->session->{mfa_id}) {
        my $mfa = pf::factory::mfa->new($self->app->session->{mfa_id});
        if(defined($mfa)){
            $self->app->session->{mfa_id} = $mfa->id;
        }
        return $mfa;
    }
    return undef;
}

=head2 show_mfa

Show the mfa template

=cut

sub show_mfa {
    my ($self, $arg) = @_;
    $arg = $arg // {},
    my $args = {
        fingerbank_info => pf::node::fingerbank_info($self->current_mac, $self->node_info),
        mfa => $self->get_mfa,
        skipable => isenabled($self->skipable),
        title => ["MFA : %s",$self->get_mfa->id],
        %{$arg},
    };
    $self->render($self->get_mfa->template, $args);
}

=head2 execute_child

Find the mfa and proceed to the actions related to it

=cut

sub execute_child {
    my ($self) = @_;

    my $mfa = $self->get_mfa();
    my $mac = $self->current_mac;
    my $args;
    
    unless($mfa){
        get_logger->info("No mfa found for $mac. Continuing.");
        $self->done();
        return;
    }
    
    get_logger->info("Found mfa " . $mfa->id . " for $mac");
    if ($self->app->request->parameters->{next} && isenabled($self->skipable)){
        $self->done();
    }
    elsif ($self->app->request->method eq "POST") {
        if(!$mfa->verify_response($self->app->hashed_params(), $self->username)) {
            $self->app->flash->{error} = "Unable to validate the multi-factor response. Please contact your local support staff.";
            $self->app->redirect("/logout");
        } 
        else {
            get_logger->info("MFA response validated, moving to the next step");
            $self->done();
        }
    }
    else {
        my $relayState = $self->app->isRootSSO ? $self->app->request->cookie("CGISESSION")->value : undef;
        my $info = $mfa->redirect_info($self->username, $self->app->session->{'captiveportal::Model::Portal::Session'}->{'dispatcherSession'}->{'_session_id'}, $relayState);
        $self->show_mfa($info);
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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


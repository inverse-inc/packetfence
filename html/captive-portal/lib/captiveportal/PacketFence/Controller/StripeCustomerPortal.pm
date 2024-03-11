package captiveportal::PacketFence::Controller::StripeCustomerPortal;
use Moose;
use namespace::autoclean;
use pf::constants;
use List::MoreUtils qw(any firstval);
use pf::node;

BEGIN { extends 'captiveportal::Base::Controller'; }

use pf::config qw($reverse_fqdn);

__PACKAGE__->config( namespace => 'stripe-customer-portal', );

=head1 NAME

captiveportal::PacketFence::Controller::StripeCustomerPortal - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub auto : Private {
    my ($self, $c) = @_;
    my $pid     = $c->user_session->{"username"};
    if(!$pid) {
        $c->response->redirect("/status/login");
        $c->detach()
    }
    $c->stash->{pid} = $pid;

    if(!$c->profile->stripeCustomerPortalEnabled) {
        $self->showError($c, "Stripe Customer Portal is not enabled on the Stripe sources of this connection profile");
        $c->detach();
    }

    my $source = $c->profile->stripeCustomerPortalSource();
    $c->stash->{source} = $source;
    if(!$source) {
        $self->showError($c, "Unable to find a Stripe source in this connection profile");
        $c->detach();
    }
    return $TRUE;
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $accounts = $c->stash->{'source'}->get_customers_by_email($c->stash->{"pid"});
    my @accounts_info;
    foreach my $account (@$accounts) {
        push @accounts_info, {
            created_at => scalar localtime($account->{created}),
            active => (any { $_->{status} eq "active" } @{$account->{subscriptions}->{data}}),
            node => node_view($_->{metadata}->{mac_address}),
            account => $account,
        };
    }
    $c->stash(
        template         => "stripe-customer-portal/select-account.html",
        accounts         => \@accounts_info,
    );
}

sub manage : Local : Args(1) {
    my ($self, $c, $cus_id) = @_;
    my $accounts = $c->stash->{'source'}->get_customers_by_email($c->stash->{"pid"});
    my $customer = firstval { $_->{id} eq $cus_id} @$accounts;
    if(!$customer) {
        $self->showError($c, "Trying to manage a customer ID that doesn't belong to this account.");
        $c->detach();
    }
    my $url = $c->stash->{source}->setupStripeCustomerPortal($cus_id, $c->request->base."stripe-customer-portal");
    if($url) {
        $c->response->redirect($url);
    }
    else {
        $self->showError($c, "Unable to create Stripe Customer Portal session");
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

package captiveportal::DynamicRouting::AuthModule::Billing;

=head1 NAME

captiveportal::DynamicRouting::AuthModule::Billing

=head1 DESCRIPTION

Billing auth module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::AuthModule';
with 'captiveportal::DynamicRouting::FieldValidation';
with 'captiveportal::DynamicRouting::Routed';
with 'captiveportal::DynamicRouting::MultiSource';

use Tie::IxHash;
use pf::log;
use List::Util qw(first);
use pf::config;
use pf::violation;
use pf::config::violation;
use pf::config::util;
use pf::util;
use pf::node;

has '+pid_field' => (default => sub { "user_email" });

has '+route_map' => (default => sub {
    tie my %map, 'Tie::IxHash', (
        '/billing' => \&index,
        '/billing/cancel' => \&cancel,
        '/billing/verify' => \&verify,
        '/billing/confirm' => \&confirm,
    );
    return \%map;
});

around qw(index cancel verify confirm) => sub {
    my $orig = shift;
    my $self = shift;
    unless( scalar(@{$self->sources}) ) {
        $self->app->error("Couldn't find any billing source");
    }
    else {
        $self->$orig();
    }
};

sub index {
    my ($self) = @_;

    $self->render('billing/index.html', {
        billing_sources => $self->sources,
        billing_tiers => $self->app->profile->billing_tiers,
        fields => $self->merged_fields,
        form => $self->form,
    });
}

sub cancel {}
sub verify {
    my ($self) = @_;

    get_logger->info("Validating payment for user : ".$self->username);

    my $request = $self->app->request;
    my $billing = $self->source();
    my $data;
    $self->session->{email} = $self->username;
    $self->session->{billed_mac} = $self->current_mac;
    eval {
        $data = $billing->verify($self->session, $request->parameters, $request->uri);
    };
    if ($@) {
        get_logger->error($@);
        $self->app->flash->{error} = "Unable to process payment";
        $self->index();
        return 0;
    }
    else {
        $self->process_transaction();
    }
}

sub process_transaction {
    my ($self) = @_;
    my $profile       = $self->app->profile;
    my $session       = $self->session;
    my $request       = $self->app->request;
    my $logger        = get_logger;
    my $mac           = $self->current_mac;

    # Transactions informations
    my $tier = $session->{'tier'};
    my $pid  = $self->username || $default_pid;
    my $billing = $self->source;


    my $info = $self->new_node_info();
    my $access_duration = normalize_time($tier->{'access_duration'});

    $info->{'pid'} = $self->username;
    $info->{'category'} = $tier->{'role'};
    $info->{'unregdate'} =
      POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $access_duration));

    if (isenabled($tier->{'use_time_balance'})) {
        $info->{'time_balance'} =
          normalize_time($tier->{'access_duration'});

        # Check if node has some access time left; if so, add it to the new duration
        my $node = node_view($mac);
        if ($node && $node->{'time_balance'} > 0) {
            if ($node->{'last_start_timestamp'} > 0) {
                # Node is active; compute the actual access time left
                my $expiration = $node->{'last_start_timestamp'} + $node->{'time_balance'};
                my $now        = time;
                if ($expiration > $now) {
                    $info->{'time_balance'} += ($expiration - $now);
                }
            }
            else {
                # Node is inactive; add the remaining access time to the purchased access time
                $info->{'time_balance'} += $node->{'time_balance'};
            }
        }
        $logger->info("Usage duration for $mac is now " . $info->{'time_balance'});
    }

    # Close violations that use the 'Accounting::BandwidthExpired' trigger
    foreach my $vid (@BANDWIDTH_EXPIRED_VIOLATIONS){
        # Close any existing violation
        violation_force_close($mac, $vid);
    }

    $self->done();

}

# we handle these ourselves
sub execute_actions {}

sub find_source {
    my ($self, $source_id) = @_;
    my $profile = $self->app->profile;
    my $billing;
    $billing = first {$_->id eq $source_id} @{$self->sources};
    unless ($billing) {
        $self->app->flash->{error} = "Your session has expired cannot access billing try again";
        return 0;
    }
    $self->source($billing);
    return 1;
}

sub confirm {
    my ($self) = @_;
    
    return $self->index() unless($self->validate_form());

    return unless($self->validate());

    my $billing = $self->source;

    my $pid  = $self->request_fields->{$self->pid_field};

    get_logger->debug("Entering billing confirmation for user $pid");

    my $data = eval {
          $billing->prepare_payment($self->app->session, $self->session->{tier}, $self->app->request->parameters, $self->app->request->uri)
    };
    if ($@) {
        get_logger->error($@);
        $self->app->flash->{error} = "An error occured while preparing the request to the external provider";
        $self->index();
        return;
    }

    $self->username($pid);

    $self->render("billing/confirm_" . $billing->type . ".html", {
        %{$data},
        billing => $billing,
        tier => $self->session->{tier},
    });
}

sub validate {
    my ($self) = @_;
    my $request = $self->app->request;
    use Data::Dumper;
    get_logger->info("parameters in the request : ".Dumper($request->param_names));
    my $source_param = first { /^billing_source_/ } $request->param_names;
    if($source_param =~ /^billing_source_(.*)/) {
        return $self->index() unless($self->find_source($1));
    } else {
        $self->app->flash->{error} = "Invalid billing source for profile";
        $self->index();
        return 0;
    }

    #Check if the billing source provided is correct
    my $selected_tier = $request->param('tier');
    unless ($selected_tier) {
        get_logger->error("No Tier selected");
        $self->app->flash->{error} = "No Tier selected";
        $self->index();
        return 0;
    }

    my $tier = $self->app->profile->getBillingTier($selected_tier);
    unless ($tier) {
        get_logger->error("Selected Tier is invalid");
        $self->app->flash->{error} = "Selected Tier is invalid";
        $self->index();
        return 0;
    }

    $self->session->{tier} = $tier;

}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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


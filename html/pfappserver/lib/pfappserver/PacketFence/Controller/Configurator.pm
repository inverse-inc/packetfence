package pfappserver::PacketFence::Controller::Configurator;

=head1 NAME

pfappserver::PacketFence::Controller::Configurator - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use HTML::Entities;
use HTTP::Status qw(:constants is_error is_success);
use Moose;

use pf::config qw(%Config);
use List::MoreUtils qw(all);
use fingerbank::Config;
#use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

# Define the order of the configurator steps.
# The id must match an action name.
my @steps = (
    { id          => 'enforcement',
      title       => 'Enforcement',
      description => 'Choose your enforcement mechanisms' },
    { id          => 'networks',
      title       => 'Networks',
      description => 'Configure network interfaces' },
    { id          => 'database',
      title       => 'Database',
      description => 'Configure MySQL' },
    { id          => 'configuration',
      title       => 'PacketFence',
      description => 'Configure various options' },
    { id          => 'admin',
      title       => 'Administration',
      description => 'Configure access to the admin interface' },
    { id          => 'fingerbank',
      title       => 'Fingerbank',
      description => 'Configure Fingerbank' },
    { id          => 'services',
      title       => 'Confirmation',
      description => 'Start the services' }
);

=head1 SUBROUTINES

=head2 begin

Set the default view to pfappserver::View::Configurator.

=cut

sub begin :Private {
    my ( $self, $c ) = @_;
    $c->stash->{current_view} = 'Configurator';
    unless($c->user_in_realm('configurator')) {
        $c->authenticate( {username => '_PF_CONFIGURATOR' } , 'configurator' );
    }
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->redirect($c->uri_for($self->action_for($steps[0]->{id})));
}

=head2 object

Configurator controller dispatcher

=cut

sub object :Chained('/') :PathPart('configurator') :CaptureArgs(0) {
    my ( $self, $c ) = @_;

    $c->stash->{installation_type} = $c->model('Configurator')->checkForUpgrade();
    if ($c->stash->{installation_type} eq $pfappserver::Model::Configurator::CONFIGURATION) {
        my $admin_url = $c->uri_for($c->controller('Admin')->action_for('index'));
        $c->log->info("Redirecting to admin interface $admin_url");
        $c->response->redirect($admin_url);
        $c->detach();
    }

    $c->stash->{steps} = \@steps;
    $self->_next_step($c);

    if ($c->action->name() ne $self->action_for('enforcement')->name &&
        (!exists($c->session->{enforcements}) || scalar($c->session->{enforcements}) == 0)) {
        # Defaults to inlinel2 mode if no mechanism has been chosen so far
        $c->session->{enforcements}->{'inlinel2'} = 1;
    }
}

=head2 _next_step

Set the next step with respect to the current action.

=cut

sub _next_step {
    my ( $self, $c ) = @_;

    my $i;
    for ($i = 0; $i <= $#steps; $i++) {
        last if ($steps[$i]->{id} eq $c->action->name);
    }

    $c->stash->{step_index} = $i + 1;
    $i++ if ($i < $#steps);
    $c->stash->{next_step} = $c->uri_for($steps[$i]->{id});
}

=head2 enforcement

Enforcement mechanisms (step 1)

=cut

sub enforcement :Chained('object') :PathPart('enforcement') :Args(0) {
    my ( $self, $c ) = @_;
    if ($c->request->method eq 'POST') {
        # Save parameters in user session
        my $enforcements = $c->request->params->{enforcement};
        $enforcements = [$enforcements] if (ref $enforcements ne 'ARRAY');
        $c->session(enforcements => {});
        map { $c->session->{enforcements}->{$_} = 1 } @$enforcements;

        if (scalar @$enforcements == 0) {
            # Make sure at least one enforcement method is selected
            $c->response->status(HTTP_PRECONDITION_FAILED);
            $c->stash->{status_msg} = $c->loc("You must choose at least one enforcement mechanism.");
            delete $c->session->{completed}->{$c->action->name};
        }
        else {
            # Step passed validation
            $c->session->{completed}->{$c->action->name} = 1;
        }

        $c->stash->{current_view} = 'JSON';
    }
    elsif (!exists($c->session->{enforcements})) {
        # Detect chosen mechanisms from networks.conf
        my $interfaces_ref = $c->model('Interface')->get('all');
        my ($status, $interfaces_types) = $c->model('Config::Network')->getTypes($interfaces_ref);
        if (is_success($status)) {
            # If some interfaces are associated to a type, find the corresponding mechanism
            my @active_types = values %{$interfaces_types};
            $c->session(enforcements => {});
            my $mechanisms_ref = $c->model('Enforcement')->getAvailableMechanisms();
            foreach my $mechanism (@{$mechanisms_ref}) {
                my $mechanism_types = $c->model('Enforcement')->getAvailableTypes($mechanism);
                my %types_lookup;
                @types_lookup{@{$mechanism_types}} = (); # built lookup table
                foreach my $type (@active_types) {
                    if (exists $types_lookup{$type}) {
                        $c->session->{enforcements}->{$mechanism} = 1;
                        last;
                    }
                }
            }
        }

        if (exists($c->session->{enforcements}) && keys(%{$c->session->{enforcements}}) > 0) {
            $c->log->info("Detected mechanisms: " . join(', ', keys %{$c->session->{enforcements}}));
        }
        else {
            # Defaults to inline mode if no mechanism has been detected
            $c->session->{enforcements}->{inlinel2} = 1;
        }
    }

}

=head2 networks

Network interfaces (step 2)

=cut

sub networks :Chained('object') :PathPart('networks') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'POST') {
        $c->stash->{current_view} = 'JSON';

        # Gateway must be specified
        my $gateway = $c->request->params->{gateway};
        unless ($gateway) {
            $c->response->status(HTTP_PRECONDITION_FAILED);
            $c->stash->{status_msg} = $c->loc("You must specifiy a gateway address.");
            delete $c->session->{completed}->{$c->action->name};
            $c->detach();
            return 0;
        }

        # Make sure all types for each enforcement is assigned to an interface
        # TODO: Shall we ignore disabled interfaces?
        my $interfaces = $c->model('Interface')->get('all');
        my @selected_types;
        foreach ( keys %$interfaces ) { push @selected_types, split(',', $interfaces->{$_}->{type}); }
        my %selected_types = map { $_ => 1 } @selected_types;
        my @missing = ();

        foreach my $enforcement (keys %{$c->session->{enforcements}}) {
            my $types_ref = $c->model('Enforcement')->getRequiredTypes($enforcement);
            foreach my $type (@{$types_ref}) {
                unless (exists $selected_types{$type} ||
                        $type eq 'other' ||
                        $type =~ m/^inline/ && grep(/^inline/, keys %selected_types) ||
                        grep {$_ eq $type || /^inline/ && $type =~ m/^inline/} @missing) {
                    push(@missing, $type);
                }
            }
        }

        if (scalar @missing > 0) {
            $c->response->status(HTTP_PRECONDITION_FAILED);
            $c->stash->{status_msg} = $c->loc("You must assign an interface to the following types: [_1]",
                                              join(", ", map { $c->loc($_) } @missing));
            delete $c->session->{completed}->{$c->action->name};
        }
        else {
            # Update the network interface configurations on system
            my ($status, $message) = $c->model('Config::System')->write_network_persistent($interfaces, $gateway);
            if (is_error($status)) {
                $c->response->status($status);
                $c->stash->{status_msg} = $message;
            }
            else {
                # Step passed validation
                $c->session->{completed}->{$c->action->name} = 1;
                $c->session->{gateway} = $gateway;
            }
        }
    }
    else {
        $c->session->{gateway} = $c->model('Config::System')->getDefaultGateway if (!defined($c->session->{gateway}));

        my $interfaces_ref = $c->model('Interface')->get('all');
        $c->stash->{interfaces} = $interfaces_ref;
        $c->stash->{seen_networks} = $c->model('Interface')->map_interface_to_networks($c->stash->{interfaces});
    }

    # Remove some CSP restrictions to accomodate Chosen (the select-on-steroid widget):
    #  - Allows use of inline source elements (eg style attribute)
    $c->stash->{csp_headers} = { style => "'unsafe-inline'" };
}

=head2 database

Database setup (step 3)

=cut

# FIXME this is not like we built the rest of pfappserver.. re-architect?
# the GET is expected to fail on first run, then the javascript calls it again and it should pass...
sub database :Chained('object') :PathPart('database') :Args(0) {
    my ( $self, $c ) = @_;

    # Default username if nothing else have already been entered (provide a pre-filled field)
    $c->session->{root_user} = 'root' if (!defined($c->session->{root_user}));

    # Check MySQLd status by fetching pid
    $c->stash->{mysqld_running} = 1 if ($c->model('Config::System')->check_mysqld_status() ne 0);

    if ($c->request->method eq 'GET') {
        delete $c->session->{completed}->{$c->action->name};
        # Check if the database and user exist
        my $database_ref = \%{$Config{'database'}};
        $c->stash->{'database'} = $database_ref;
        # hash-slice assigning values to the list
        my ($pf_user, $pf_pass, $pf_db) = @{$database_ref}{qw/user pass db/};
        if ($pf_user && $pf_pass && $pf_db) {
            # throwing away result since we don't use it
            my ($status) = $c->model('DB')->connect($pf_db, $pf_user, $pf_pass);
            if (is_success($status)) {
                # everything has been done successfully
                $c->session->{completed}->{$c->action->name} = 1;
                # we need to restart mariadb so that it applies the network configuration
                system("sudo /usr/bin/systemctl restart packetfence-mariadb");
            }
        }
    }
}

=head2 configuration

PacketFence minimal configuration (step 4)

=cut

sub configuration :Chained('object') :PathPart('configuration') :Args(0) {
    my ( $self, $c ) = @_;
    my $logger = $c->log;

    my $pf_model = $c->model('Config::Pf');
    if ($c->request->method eq 'GET') {
        my (%config, $status, $general_ref, $alerting_ref, $advanced_ref);
        ($status, $general_ref) = $pf_model->read('general');
        if (is_success($status)) {
            ($status, $alerting_ref) = $pf_model->read('alerting');
            if (is_success($status)) {
                ($status, $advanced_ref) = $pf_model->read('advanced');
                if (is_success($status)) {
                    @config{qw(
                                  general.domain
                                  general.hostname
                                  general.dhcpservers
                                  alerting.emailaddr
                                  alerting.smtpserver
                                  advanced.hash_passwords
                             )} = (
                                   @$general_ref{qw(
                                                       domain
                                                       hostname
                                                       dhcpservers
                                                  )},
                                   @$alerting_ref{qw(
                                                       emailaddr
                                                       smtpserver
                                                  )},
                                   @$advanced_ref{hash_passwords}
                                  );
                    $c->stash->{'config'} = \%config;
                }
            }
        }
    }
    elsif ($c->request->method eq 'POST') {
        # Save configuration
        my ( $status, $message ) = (HTTP_OK);
        my $general_domain          = $c->request->params->{'general.domain'};
        my $general_hostname        = $c->request->params->{'general.hostname'};
        my $general_dhcpservers     = $c->request->params->{'general.dhcpservers'};
        my $alerting_emailaddr      = $c->request->params->{'alerting.emailaddr'};
        my $alerting_smtpserver     = $c->request->params->{'alerting.smtpserver'};
        my $advanced_hash_passwords = $c->request->params->{'advanced.hash_passwords'};

        unless ($general_domain && $general_hostname && $general_dhcpservers &&
                $alerting_emailaddr && $advanced_hash_passwords) {
            ($status, $message) = ( HTTP_BAD_REQUEST, 'Some required parameters are missing.' );
        }
        if (is_success($status)) {
            my $pf_model = $c->model('Config::Pf');
            ( $status, $message ) = $pf_model->update('general' => {
                'domain'      => $general_domain,
                'hostname'    => $general_hostname,
                'dhcpservers' => $general_dhcpservers,
            });
            if (is_error($status)) {
                $logger->error($message);
                delete $c->session->{completed}->{$c->action->name};
            }
            ( $status, $message ) = $pf_model->update('alerting' => {
                'emailaddr'  => $alerting_emailaddr,
            });
            if (is_error($status)) {
                $logger->error($message);
                delete $c->session->{completed}->{$c->action->name};
            }
            if($alerting_smtpserver) {
                ( $status, $message ) = $pf_model->update('alerting' => {
                    'smtpserver'  => $alerting_smtpserver,
                });
                if (is_error($status)) {
                    $logger->error($message);
                    delete $c->session->{completed}->{$c->action->name};
                }
            }
            ( $status, $message ) = $pf_model->update('advanced' => {
                'hash_passwords'  => $advanced_hash_passwords
            });
            if (is_error($status)) {
                $logger->error($message);
                delete $c->session->{completed}->{$c->action->name};
            } else {
                $pf_model->commit();
            }
            my $network_model = $c->model('Config::Network');

            # Update networks.conf file with correct domain-names for each networks
            my $networks;
            ($status, $networks) = $network_model->readAll();
            foreach my $network ( @$networks ) {
                my $type = $network->{type};
                $network_model->update($network->{network}, {'domain-name' => $type . "." . $general_domain});
            }
            $network_model->commit();

        }
        if (is_error($status)) {
            $logger->error($message);
            $c->response->status($status);
            $c->stash->{status_msg} = $message;
        }
        else {
            $c->session->{completed}->{$c->action->name} = 1;
        }
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 admin

Administrator account (step 5)

=cut

sub admin :Chained('object') :PathPart('admin') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'POST') {
        my ($status, $message) = ( HTTP_OK );
        my $admin_user      = $pf::config::ADMIN_USERNAME;
        my $admin_password  = $c->request->params->{admin_password};

        unless ( $admin_user && $admin_password ) {
            ($status, $message) = ( HTTP_BAD_REQUEST, 'Some required parameters are missing.' );
        }
        if ( is_success($status) ) {
            ($status, $message) = $c->model('DB')->resetUserPassword($admin_user, $admin_password);
        }
        if ( is_success($status) ) {
            $c->session(admin_user => $admin_user);
            $c->session->{completed}->{$c->action->name} = 1;
        } else {
            delete $c->session->{admin_user};
            delete $c->session->{completed}->{$c->action->name};
            $c->response->status($status);
        }

        $c->stash->{status_msg} = $message;
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 fingerbank

Fingerbank setup (step 6)

=cut

sub fingerbank :Chained('object') :PathPart('fingerbank') :Args(0) {
    my ($self, $c) = @_;
    $c->session->{completed}->{$c->action->name} = 1;
    my $config = fingerbank::Config::get_config;
    $c->stash->{fingerbank_api_key} = $config->{'upstream'}{'api_key'};
}

=head2 services

Confirmation and services launch (step 6)

=cut

sub services :Chained('object') :PathPart('services') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'GET') {

        $c->session->{started} = 0;
        my $completed = $c->session->{completed};
        $c->stash->{completed} = 1;
        foreach my $step (@steps) {
            next if ($step->{id} eq $c->action->name); # Don't test the current action
            unless ($completed->{$step->{id}}) {
                $c->stash->{completed} = 0;
                last;
            }
        }
        if ($c->stash->{completed}) {
            my ($status, $error) = $c->model('PfConfigAdapter')->reloadConfiguration();
            if ( is_error($status) ) {
                $c->log->error("an error trying to reload the configuration");
                $c->response->status($status);
                $c->stash->{'error'} = $error;
                $c->detach();
            }
            $c->stash->{'admin_ip'} = $c->model('PfConfigAdapter')->getWebAdminIp();
            $c->stash->{'admin_port'} = $c->model('PfConfigAdapter')->getWebAdminPort();
        }

        my ($status, $services) = $c->model('Services')->status(1);
        if ( is_success($status) ) {
            $c->log->info("successfully listed services");
            $c->stash($services);
        }
        else {
            $c->log->error("an error trying to list the services");
            $c->response->status($status);
            $c->stash->{'error'} = $services;
        }
    } elsif ($c->request->method eq 'POST') {
        # Start the services
        if (!$c->session->{started}) {
            $c->session->{started} = 1;
            system("sudo /usr/local/pf/bin/pfcmd service pf updatesystemd");
            # restart pfconfig
            $c->model("Config::System")->restart_pfconfig();
            $c->detach(Service => 'pf_start');
        } else {
            my ($HTTP_CODE, $services) = $c->model('Services')->status(1);
            if( all { $_->{status} ne '0' } @{ $services->{services} } ) {
                $c->model('Configurator')->update_currently_at();
            }
            $c->controller('Service')->_process_model_results_as_json($c, $HTTP_CODE, $services);
        }
    }
}

=head1 AUTHORS

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

package configurator::Controller::Wizard;

=head1 NAME

configurator::Controller::Wizard - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTML::Entities;
use HTTP::Status qw(:constants is_error is_success);
use JSON;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 SUBROUTINES

=over

=item index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->redirect($c->uri_for($self->action_for('step1')));
}

=item object

Wizard controller dispatcher

=cut
sub object :Chained('/') :PathPart('wizard') :CaptureArgs(0) {
    my ( $self, $c ) = @_;

    $c->stash->{installation_type} = $c->model('Wizard')->checkForUpgrade();
}

=item step1

Enforcement mechanisms and network interfaces

=cut
sub step1 :Chained('object') :PathPart('step1') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'POST') {
        # Save parameters in user session
        my $data = decode_json($c->request->params->{json});
        $c->session(gateway => $data->{gateway},
                    dns => $data->{dns},
                    enforcements => {});
        $c->stash(interfaces_types => $data->{interfaces_types});
        map { $c->session->{enforcements}->{$_} = 1 } @{$data->{enforcements}};

        # Make sure all types for each enforcement is assigned to an interface
        # TODO: Shall we ignore disabled interfaces?
        my @selected_types = values %{$data->{interfaces_types}};
        my %seen;
        my @missing = ();
        @seen{@selected_types} = ( ); # build lookup table

        foreach my $enforcement (@{$data->{enforcements}}) {
            my $types_ref = $c->model('Enforcement')->getAvailableTypes($enforcement);
            foreach my $type (@{$types_ref}) {
                push(@missing, $c->loc($type)) unless exists $seen{$type} || $type eq 'other';
            }
        }

        if (scalar @missing > 0) {
            $c->response->status($STATUS::PRECONDITION_FAILED);
            $c->stash->{status_msg} = $c->loc("You must assign an interface to the following types: [_1]", join(", ", @missing));
            delete $c->session->{completed}->{step1};
        }
        elsif (scalar @{$data->{enforcements}} == 0) {
            # Make sure at least one enforcement method is selected
            $c->response->status($STATUS::PRECONDITION_FAILED);
            $c->stash->{status_msg} = $c->loc("You must choose at least one enforcement mechanism.");
            delete $c->session->{completed}->{step1};
        }
        # TODO move IP validation to something provided by core (once in model I guess)
# XXX needs to check each interfaces in a loop for inline
#        elsif ($data->{interfaces_types}->{$interface} =~ /^inline$/i && $data->{dns} =~ /\d{1,3}\.\d{1,3}\.\d{1,3}.\d{1,3}/) {
#            # DNS must be set if in inline enforcement
#            $c->response->status($STATUS::PRECONDITION_FAILED);
#            $c->stash->{status_msg} = $c->loc(
#                "A valid DNS server must be provided for Inline enforcement. "
#                . "If you are unsure you can always put in your ISP's DNS or a global DNS like 4.2.2.1."
#            );
#            delete $c->session->{completed}->{step1};
#        }
        else {

            # Update networks.conf and pf.conf
            my $networksModel = $c->model('Config::Networks');
            my $configModel = $c->model('Config::Pf');
            foreach my $interface (keys %{$data->{interfaces_types}}) {
                my $interface_ref = $c->model('Interface')->get($interface)->{$interface};
    
                # we ignore interface type 'Other' (it basically means unsupported in configurator)
                next if ( $data->{interfaces_types}->{$interface} =~ /^other$/i );
    
                # we delete interface type 'None'
                if ( $data->{interfaces_types}->{$interface} =~ /^none$/i ) {
                    $networksModel->delete($interface_ref->{network}) if ($networksModel->exist($interface_ref->{network}));
                    $configModel->delete_interface($interface) if ($configModel->exist_interface($interface));
                }
                # otherwise we update pf.conf and networks.conf
                else {
                    # we willingly silently ignore errors if interface already exists
                    # TODO have a wrapper that does both?
                    $configModel->create_interface($interface);
                    $configModel->update_interface(
                        $interface,
                        _prepare_interface_for_pfconf($interface, $interface_ref, $data->{interfaces_types}->{$interface})
                    );
    
                    # FIXME refactor that!
                    # and we must create a network portion for the following types
                    if ( $data->{interfaces_types}->{$interface} =~ /^vlan-isolation$|^vlan-registration$/i ) {
                        $networksModel->create($interface_ref->{network});
                        $networksModel->update(
                            $interface_ref->{network}, {
                                type => $data->{interfaces_types}->{$interface},
                                netmask => $interface_ref->{'netmask'},
                                # FIXME push these default values further down in the stack
                                # (into pf::config, pf::services, etc.)
                                gateway => $interface_ref->{'ipaddress'},
                                dns => $interface_ref->{'ipaddress'},
                                dhcp_start => Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(10),
                                dhcp_end => Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(-10),
                                dhcp_default_lease_time => 300,
                                dhcp_default_lease_time => 600,
                                named => 'enabled',
                                dhcpd => 'enabled',
                            }
                        );
                    }
                    elsif ( $data->{interfaces_types}->{$interface} =~ /^inline$/i ) {
                        $networksModel->create($interface_ref->{network});
                        $networksModel->update(
                            $interface_ref->{network}, {
                                type => $data->{interfaces_types}->{$interface},
                                netmask => $interface_ref->{'netmask'},
                                # FIXME push these default values further down in the stack 
                                # (into pf::config, pf::services, etc.)
                                gateway => $interface_ref->{'ipaddress'},
                                dns => $data->{'dns'},
                                dhcp_start => Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(10),
                                dhcp_end => Net::Netmask->new(@{$interface_ref}{qw(ipaddress netmask)})->nth(-10),
                                dhcp_default_lease_time => 24 * 60 * 60,
                                dhcp_default_lease_time => 24 * 60 * 60,
                                named => 'enabled',
                                dhcpd => 'enabled',
                            }
                        );
                    }
                }
            }

            # Step passed validation
            $c->session->{completed}->{step1} = 1;
        }

        $c->stash->{current_view} = 'JSON';
    }
    else {
        my $interfaces_ref = $c->model('Interface')->get('all');
        $c->stash(interfaces => $interfaces_ref);
        $c->stash(types => $c->model('Enforcement')->getAvailableTypes(['inline', 'vlan']));
        my ($status, $interfaces_types) = $c->model('Config::Networks')->get_types($interfaces_ref);
        if (is_success($status)) {
            $c->stash->{interfaces_types} = _prepare_types_for_display($c, $interfaces_ref, $interfaces_types);
        }
        # $c->stash(gateway => ?)
        # $c->stash(dns => ?)
    }
}

=item _prepare_interface_for_pfconf

Process parameters to build a proper pf.conf interface section.

=cut
# TODO push hardcoded strings as constants (or re-use core constants)
# this might imply a rework of this out of the controller into the model
sub _prepare_interface_for_pfconf {
    my ($int, $int_model, $type) = @_;

    my $int_config_ref = {
        ip => $int_model->{'ipaddress'},
        mask => $int_model->{'netmask'},
    };

    # logic to match our awkward relationship between pf.conf's type and 
    # enforcement with networks.conf's type
    if ($type =~ /^vlan/i) {
        $int_config_ref->{'type'} = 'internal';
        $int_config_ref->{'enforcement'} = 'vlan';
    }
    elsif ($type =~ /^inline$/i) {
        $int_config_ref->{'type'} = 'internal';
        $int_config_ref->{'enforcement'} = 'inline';
    }
    else {
        # here we oversimplify a bit, type supports multivalues but it's 
        # out of scope for now
        $int_config_ref->{'type'} = $type;
    }

    return $int_config_ref;
}

=item _prepare_types_for_display

Process pf.conf's interface type and enforcement and networks.conf's type 
and present something that is friendly to the user.

=cut
# TODO push hardcoded strings as constants (or re-use core constants)
# this might imply a rework of this out of the controller into the model
sub _prepare_types_for_display {
    my ($c, $interfaces_ref, $interfaces_types_ref) = @_;

    my $display_int_types_ref;
#$DB::single=1;
    foreach my $interface (keys %$interfaces_ref) {
        # if the interface is in interfaces_types then take that value
        if (defined($interfaces_types_ref->{$interface})) {
            $display_int_types_ref->{$interface} = $interfaces_types_ref->{$interface};
        }
        # otherwise rely on pf.conf's info
        else {
            my $type = $c->model('Config::Pf')->read_interface_value($interface, 'type');
            # since type is a multi-value field (comma separated), we need to do something like this
            # you'll notice that we only support management for now
            $type = ($type =~ /management|managed/i) ? 'management' : 'other';
            $display_int_types_ref->{$interface} = $type;
        }
    }
    return $display_int_types_ref;
}

=item step2

Database setup

=cut
sub step2 :Chained('object') :PathPart('step2') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'GET') {
        # Check if the database and user exist
        my ($status, $result_ref) = $c->model('Config::Pf')->read_value(
            ['database.user', 'database.pass', 'database.db']
        );
        if (is_success($status)) {
            $c->stash->{'db'} = $result_ref;
            # hash-slice assigning values to the list
            my ($pf_user, $pf_pass, $pf_db) = @{$result_ref}{qw/database.user database.pass database.db/};
            if ($pf_user && $pf_pass && $pf_db) {
                # throwing away result since we don't use it
                ($status) = $c->model('DB')->connect($pf_db, $pf_user, $pf_pass);
            }
        }
        if (is_success($status)) {
            $c->session->{completed}->{step2} = 1;
        }
        else {
            delete $c->session->{completed}->{step2};
        }
    }
}

=item step3

PacketFence minimal configuration

=cut
sub step3 :Chained('object') :PathPart('step3') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'GET') {
        my ($status, $result_ref) = $c->model('Config::Pf')->read_value(
            ['general.domain', 'general.hostname', 'general.dhcpservers', 'alerting.emailaddr']
        );
        if (is_success($status)) {
            $c->stash->{'config'} = $result_ref;
        }
    }
    elsif ($c->request->method eq 'POST') {
        # Save configuration
        my ( $status, $message ) = ($STATUS::OK);
        my $general_domain      = $c->request->params->{'general.domain'};
        my $general_hostname    = $c->request->params->{'general.hostname'};
        my $general_dhcpservers = $c->request->params->{'general.dhcpservers'};
        my $alerting_emailaddr  = $c->request->params->{'alerting.emailaddr'};

        unless ($general_domain && $general_hostname && $general_dhcpservers && $alerting_emailaddr) {
            ($status, $message) = ( $STATUS::BAD_REQUEST, 'Some required parameters are missing.' );
        }
        if (is_success($status)) {
            my ( $status, $message ) = $c->model('Config::Pf')->update({
                'general.domain'      => $general_domain,
                'general.hostname'    => $general_hostname,
                'general.dhcpservers' => $general_dhcpservers,
                'alerting.emailaddr'  => $alerting_emailaddr
            });
            if (is_error($status)) {
                delete $c->session->{completed}->{step3};
            }
        }
        if (is_error($status)) {
            $c->response->status($status);
            $c->stash->{status_msg} = $message;
        }
        else {
            $c->session->{completed}->{step3} = 1;
        }
        $c->stash->{current_view} = 'JSON';
    }
}

=item step4

Administrator account

=cut
sub step4 :Chained('object') :PathPart('step4') :Args(0) {
    my ( $self, $c ) = @_;

    # See create_admin
}

=item step5

Confirmation and services launch

=cut
sub step5 :Chained('object') :PathPart('step5') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'GET') {

        my $completed = $c->session->{completed};
        $c->stash->{completed} =
          $completed->{step1}
            && $completed->{step2}
              && $completed->{step3}
                && $completed->{step4};

        if ($c->stash->{completed}) {
            $c->model('PfConfigAdapter')->reloadConfiguration();
            $c->stash->{'admin_ip'} = $c->model('PfConfigAdapter')->getWebAdminIp();
            $c->stash->{'admin_port'} = $c->model('PfConfigAdapter')->getWebAdminPort();
        }

        my ($status, $services_status) = $c->model('Services')->status();
        if ( is_success($status) ) {
            $c->log->info("successfully listed services");
            $c->stash->{'services_status'} = $services_status;
        }
        if ( is_error($status) ) {
            $c->log->info("an error trying to list the services");
            $c->response->status($status);
        }
    }

    # Start the services
    elsif ($c->request->method eq 'POST') {

        # actually try to start the services
        my ($status, $service_start_output) = $c->model('Services')->start();
        # if we detect an error later, we will be able to display the output
        # this will be done on the client side
        $c->stash->{'error'} = encode_entities($service_start_output);
        if ( is_error($status) ) {
            $c->response->status($status);
            $c->stash->{status_msg} = $service_start_output;
        }
        # success: list the services
        else {
            my ($status, $services_status) = $c->model('Services')->status();
            if ( is_success($status) ) {
                $c->log->info("successfully listed services");
                $c->stash->{'services'} = $services_status;
            }
            else {
                $c->response->status($status);
                $c->log->info('problem trying to list the services');
                $c->stash->{status_msg} = $services_status;
            }
        }
        $c->stash->{current_view} = 'JSON';
    }
}

=item reset_password

Reset the root password (step 2)

=cut
sub reset_password :Path('reset_password') :Args(0) {
    my ( $self, $c ) = @_;

    my ($status, $message) = ( $STATUS::OK );
    my $root_user      = $c->request->params->{root_user};
    my $root_password  = $c->request->params->{root_password_new};

    unless ( $root_user && $root_password ) {
        ($status, $message) = ( $STATUS::BAD_REQUEST, 'Some required parameters are missing.' );
    }
    if ( is_success($status) ) {
        ($status, $message) = $c->model('DB')->secureInstallation($root_user, $root_password);
    }
    if ( is_error($status) ) {
        $c->response->status($status);
    }

    $c->stash->{status_msg} = $message;
    $c->stash->{current_view} = 'JSON';
}

=item create_admin

Create the administrative user (step 4)

=cut
sub create_admin :Path('create_admin') :Args(0) {
    my ( $self, $c ) = @_;

    my ($status, $message) = ( $STATUS::OK );
    my $admin_user      = $c->request->params->{admin_user};
    my $admin_password  = $c->request->params->{admin_password};

    unless ( $admin_user && $admin_password ) {
        ($status, $message) = ( $STATUS::BAD_REQUEST, 'Some required parameters are missing.' );
    }
    if ( is_success($status) ) {
        ($status, $message) = $c->model('Wizard')->createAdminUser($admin_user, $admin_password);
    }
    if ( is_success($status) ) {
        $c->session(admin_user => $admin_user);
        $c->session->{completed}->{step4} = 1;
    } else {
        delete $c->session->{admin_user};
        delete $c->session->{completed}->{step4};
        $c->response->status($status);
    }

    $c->stash->{status_msg} = $message;
    $c->stash->{current_view} = 'JSON';
}

=back

=head1 AUTHORS

Derek Wuelfrath <dwuelfrath@inverse.ca>

Francis Lachapelle <flachapelle@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

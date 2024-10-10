package pf::UnifiedApi::Controller::Config::MaintenanceTasks;

=head1 NAME

pf::UnifiedApi::Controller::Config::MaintenanceTasks -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::MaintenanceTasks

=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config::Subtype);
use Mojo::IOLoop;
use pf::factory::pfcron::task;

has 'config_store_class' => 'pf::ConfigStore::Cron';
has 'form_class' => 'pfappserver::Form::Config::Pfcron';
has 'primary_key' => 'maintenance_task_id';

use pf::ConfigStore::Cron;
use pfappserver::Form::Config::Pfcron::acct_maintenance;
use pfappserver::Form::Config::Pfcron::auth_log_cleanup;
use pfappserver::Form::Config::Pfcron::certificates_check;
use pfappserver::Form::Config::Pfcron::pki_certificates_check;
use pfappserver::Form::Config::Pfcron::cleanup_chi_database_cache;
use pfappserver::Form::Config::Pfcron::cluster_check;
use pfappserver::Form::Config::Pfcron::fingerbank_data_update;
use pfappserver::Form::Config::Pfcron::ip4log_cleanup;
use pfappserver::Form::Config::Pfcron::ip6log_cleanup;
use pfappserver::Form::Config::Pfcron::locationlog_cleanup;
use pfappserver::Form::Config::Pfcron::node_cleanup;
use pfappserver::Form::Config::Pfcron::nodes_maintenance;
use pfappserver::Form::Config::Pfcron::option82_query;
use pfappserver::Form::Config::Pfcron::person_cleanup;
use pfappserver::Form::Config::Pfcron::provisioning_compliance_poll;
use pfappserver::Form::Config::Pfcron::radius_audit_log_cleanup;
use pfappserver::Form::Config::Pfcron::switch_cache_lldpLocalPort_description;
use pfappserver::Form::Config::Pfcron::security_event_maintenance;
use pfappserver::Form::Config::Pfcron::password_of_the_day;
use pfappserver::Form::Config::Pfcron::acct_cleanup;
use pfappserver::Form::Config::Pfcron::dns_audit_log_cleanup;
use pfappserver::Form::Config::Pfcron::admin_api_audit_log_cleanup;
use pfappserver::Form::Config::Pfcron::bandwidth_maintenance;
use pfappserver::Form::Config::Pfcron::ubiquiti_ap_mac_to_ip;
use pfappserver::Form::Config::Pfcron::purge_binary_logs;
use pfappserver::Form::Config::Pfcron::node_current_session_cleanup;
use pfappserver::Form::Config::Pfcron::flush_radius_audit_log;
use pfappserver::Form::Config::Pfcron::flush_dns_audit_log;
use pfappserver::Form::Config::Pfcron::pfflow;

our %TYPES_TO_FORMS = (
    map { $_ => "pfappserver::Form::Config::Pfcron::$_" } qw(
      acct_maintenance
      auth_log_cleanup
      certificates_check
      pki_certificates_check
      cleanup_chi_database_cache
      cluster_check
      fingerbank_data_update
      ip4log_cleanup
      ip6log_cleanup
      locationlog_cleanup
      node_cleanup
      nodes_maintenance
      option82_query
      person_cleanup
      provisioning_compliance_poll
      radius_audit_log_cleanup
      dns_audit_log_cleanup
      switch_cache_lldpLocalPort_description
      security_event_maintenance
      password_of_the_day
      acct_cleanup
      admin_api_audit_log_cleanup
      bandwidth_maintenance
      ubiquiti_ap_mac_to_ip
      purge_binary_logs
      node_current_session_cleanup
      flush_radius_audit_log
      flush_dns_audit_log
      pfflow
    )
);

sub type_lookup {
    return \%TYPES_TO_FORMS;
}

=head2 form_process_parameters_for_cleanup

form_process_parameters_for_cleanup

=cut

sub form_process_parameters_for_cleanup {
    my ($self, $item) = @_;
    return (
        $self->SUPER::form_process_parameters_for_cleanup($item),
        active => [
            qw(description)
        ],
    );
}

sub run {
    my ($self) = @_;
    my $id = $self->id;
    Mojo::IOLoop->subprocess(
        sub {
            my ($subprocess) = @_;
            my $task = pf::factory::pfcron::task->new($id, {});
            if (defined $task) {
                $task->run();
            } else {
                exec('/usr/local/pf/sbin/pfcron', $id);
            }

            return {};
        },
        sub {
            my ($subprocess, $err, $results) = @_;
            return $self->render(200, json => $results);
        }
    )
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

1;

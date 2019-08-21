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

has 'config_store_class' => 'pf::ConfigStore::Pfmon';
has 'form_class' => 'pfappserver::Form::Config::Pfmon';
has 'primary_key' => 'maintenance_task_id';

use pf::ConfigStore::Pfmon;
use pfappserver::Form::Config::Pfmon::acct_maintenance;
use pfappserver::Form::Config::Pfmon::auth_log_cleanup;
use pfappserver::Form::Config::Pfmon::certificates_check;
use pfappserver::Form::Config::Pfmon::cleanup_chi_database_cache;
use pfappserver::Form::Config::Pfmon::cluster_check;
use pfappserver::Form::Config::Pfmon::fingerbank_data_update;
use pfappserver::Form::Config::Pfmon::inline_accounting_maintenance;
use pfappserver::Form::Config::Pfmon::ip4log_cleanup;
use pfappserver::Form::Config::Pfmon::ip6log_cleanup;
use pfappserver::Form::Config::Pfmon::locationlog_cleanup;
use pfappserver::Form::Config::Pfmon::node_cleanup;
use pfappserver::Form::Config::Pfmon::nodes_maintenance;
use pfappserver::Form::Config::Pfmon::option82_query;
use pfappserver::Form::Config::Pfmon::person_cleanup;
use pfappserver::Form::Config::Pfmon::populate_ntlm_redis_cache;
use pfappserver::Form::Config::Pfmon::provisioning_compliance_poll;
use pfappserver::Form::Config::Pfmon::radius_audit_log_cleanup;
use pfappserver::Form::Config::Pfmon::switch_cache_lldpLocalPort_description;
use pfappserver::Form::Config::Pfmon::security_event_maintenance;
use pfappserver::Form::Config::Pfmon::password_of_the_day;
use pfappserver::Form::Config::Pfmon::acct_cleanup;
use pfappserver::Form::Config::Pfmon::dns_audit_log_cleanup;

our %TYPES_TO_FORMS = (
    map { $_ => "pfappserver::Form::Config::Pfmon::$_" } qw(
      acct_maintenance
      auth_log_cleanup
      certificates_check
      cleanup_chi_database_cache
      cluster_check
      fingerbank_data_update
      inline_accounting_maintenance
      ip4log_cleanup
      ip6log_cleanup
      locationlog_cleanup
      node_cleanup
      nodes_maintenance
      option82_query
      person_cleanup
      populate_ntlm_redis_cache
      provisioning_compliance_poll
      radius_audit_log_cleanup
      dns_audit_log_cleanup
      switch_cache_lldpLocalPort_description
      security_event_maintenance
      password_of_the_day
      acct_cleanup
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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;


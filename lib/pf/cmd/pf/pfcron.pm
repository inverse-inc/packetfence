package pf::cmd::pf::pfcron;

#
# Update the tasks with the following command
# ls lib/pfappserver/Form/Config/Pfcron | xargs  basename -s .pm | sort | perl -pi -e'$_="=item ${_}\n"'
#

=head1 NAME

pf::cmd::pf::pfcron -

=head1 SYNOPSIS

pfcmd pfcron <task> [options...]

=head2 tasks

=over

=item acct_cleanup

=item acct_maintenance

=item admin_api_audit_log_cleanup

=item auth_log_cleanup

=item bandwidth_maintenance

=item bandwidth_maintenance_session

=item certificates_check

=item pki_certificates_check

=item cleanup_chi_database_cache

=item cluster_check

=item dns_audit_log_cleanup

=item fingerbank_data_update

=item ip4log_cleanup

=item ip6log_cleanup

=item locationlog_cleanup

=item node_cleanup

=item nodes_maintenance

=item option82_query

=item password_of_the_day

=item person_cleanup

=item provisioning_compliance_poll

=item radius_audit_log_cleanup

=item security_event_maintenance

=item switch_cache_lldpLocalPort_description

=item ubiquiti_ap_mac_to_ip

=item purge_binary_logs

=back

=head1 DESCRIPTION

pf::cmd::pf::pfcron

=cut

use strict;
use warnings;
use pf::config::pfcron qw(%ConfigCron);
use pf::constants::exit_code qw($EXIT_SUCCESS);
use pf::constants;
use pf::factory::pfcron::task;
use base qw(pf::cmd);

=head2 parseArgs

parse args of pfcron task

=cut

sub parseArgs {
    my ($self) = @_;
    my ($task_id, @args) = $self->args;
    return 0 unless defined $task_id;
    unless (exists $ConfigCron{$task_id}) {
        print STDERR "$task_id is not a valid task\n";
        return 0;
    }
    unless ($self->_parse_attributes(@args)) {
        return 0;
    }
    $self->{task_id}  = $task_id;
    return 1;
}

=head2 _run

Run the pfcron task

=cut

sub _run {
    my ($self) = @_;
    my $task_id = $self->{task_id};
    my $params = $self->{params};
    my $task = eval {pf::factory::pfcron::task->new($task_id, $params)};
    if ($@) {
        print STDERR "Error creating: $@\n";
        return 1;
    }

    if (defined $task) {
        $task->run();
    } else {
        exec('/usr/local/pf/sbin/pfcron', map {/^(.*)$/;$1} $self->args);
    }

    print "task $task_id finished\n"; 
    return $EXIT_SUCCESS;
}

=head2 _parse_attributes

parse and validate the arguments for 'pfcmd pfcron <task> [args]' command

=cut

sub _parse_attributes {
    my ($self,@attributes) = @_;
    my %params;
    for my $attribute (@attributes) {
        if($attribute =~ /^([a-zA-Z0-9_-]+)=(.*)$/ ) {
            $params{$1} = $2;
        } else {
            print STDERR "$attribute is incorrectly formatted\n";
            return 0;
        }
    }
    $self->{params} = \%params;
    return 1;
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


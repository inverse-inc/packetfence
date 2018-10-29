package pfappserver::PacketFence::Controller::Node;

=head1 NAME

pfappserver::PacketFence::Controller::Node - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use pf::constants qw($TRUE $FALSE);
use pf::admin_roles;
use namespace::autoclean;
use POSIX;
use pf::config qw(%Config);
use pf::util;
use pf::violation;

use pfappserver::Form::Node;
use pfappserver::Form::Node::Create::Import;


BEGIN { extends 'pfappserver::Base::Controller'; }
with 'pfappserver::Role::Controller::BulkActions';

__PACKAGE__->config(
    action => {
        bulk_close           => { AdminRole => 'NODES_UPDATE' },
        bulk_register        => { AdminRole => 'NODES_UPDATE' },
        bulk_deregister      => { AdminRole => 'NODES_UPDATE' },
        bulk_apply_role      => { AdminRole => 'NODES_UPDATE' },
        bulk_apply_violation => { AdminRole => 'NODES_UPDATE' },
        bulk_restart_switchport => { AdminRole => 'NODES_UPDATE' },
        bulk_reevaluate_access  => { AdminRole => 'NODES_UPDATE' },
    },
    action_args => {
        '*' => { model => 'Node' },
        'advanced_search' => { model => 'Search::Node', form => 'NodeSearch' },
        'simple_search' => { model => 'Search::Node', form => 'NodeSearch' },
        'search' => { model => 'Search::Node', form => 'NodeSearch' },
        'index' => { model => 'Search::Node', form => 'NodeSearch' },
    }
);

our %DEFAULT_COLUMNS = map { $_ => 1 } qw/status mac computername pid last_ip device_class category online tenant_name/;

=head1 SUBROUTINES


=head2 index

=cut

sub index :Path :Args(0) :AdminRole('NODES_READ') {
    my ( $self, $c ) = @_;
    $c->stash(template => 'node/search.tt', from_form => "#empty");
    $c->go('search');
}

=head2 search

Perform an advanced search using the Search::Node model

=cut

sub search :Local :Args() :AdminRole('NODES_READ') {
    my ($self, $c) = @_;
    my ($status, $status_msg, $result, $violations);
    my %search_results;
    my $model = $self->getModel($c);
    my $form = $self->getForm($c);
    my $request = $c->request();
    my $by = $request->param('by') || 'mac';
    my $direction = $request->param('direction') || 'asc';

    # Store columns in the session
    my $columns = $request->params->{'column'};
    if ($columns) {
        $columns = [$columns] if (ref($columns) ne 'ARRAY');
        my %columns_hash = map { $_ => 1 } @{$columns};
        my %params = ( 'nodecolumns' => \%columns_hash );
        $c->session(%params);
    }

    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = $form->field_errors;
        $c->stash(current_view => 'JSON');
    }
    else {
        my $query = $form->value;
        $query->{by} = 'mac' unless ($query->{by});
        $query->{direction} = 'asc' unless ($query->{direction});
        ($status, $result) = $model->search($query);
        if (is_success($status)) {
            $c->stash(form => $form);
            $c->stash($result);
        }
    }

    (undef, $result) = $c->model('Config::Roles')->listFromDB();
    (undef, $violations ) = $c->model('Config::Violations')->readAll();
    $c->stash(
        status_msg => $status_msg,
        roles => $self->get_allowed_node_roles($c),
        violations => $violations,
        by => $by,
        direction => $direction,
    );
    unless ($c->session->{'nodecolumns'}) {
        # Set default visible columns
        $c->session( nodecolumns => \%DEFAULT_COLUMNS );
    }
    $c->stash->{switches} = $self->_get_switches_metadata($c);
    $c->stash->{search_action} = $c->action;

    for my $item (@{$c->stash->{items}}) {
        my $switch_ip = $item->{switch_ip};
        if ($switch_ip) {
            my $switch = $c->stash->{switches}{$switch_ip};
            if ($switch) {
                $item->{switch_description} = $switch->{description} || "";
            }
        }
    }

    if($c->request->param('export')) {
        $c->stash->{current_view} = "CSV";
        $c->stash->{columns} = [keys(%{$c->session->{'nodecolumns'}})];
    }

    $c->response->status($status);
}

=head2 simple_search

Perform an advanced search using the Search::Node model

=cut

sub simple_search :Local :Args() :AdminRole('NODES_READ') {
    my ($self, $c) = @_;
    $c->forward('search');
    $c->stash(template => 'node/search.tt', from_form => "#simpleNodeSearch");
}

=head2 advanced_search

Perform an advanced search using the Search::Node model

=cut

sub advanced_search :Local :Args() :AdminRole('NODES_READ') {
    my ($self, $c) = @_;
    $c->forward('search');
    $c->stash(template => 'node/search.tt', from_form => "#advancedSearch");
}

=head2 create

Create one node or import a CSV file.

=cut

sub create :Local : AdminRole('NODES_CREATE') {
    my ($self, $c) = @_;

    my ($roles, $node_status, $form_single, $form_import, $params, $type);
    my ($status, $result, $message);

    $roles = $self->get_allowed_node_roles($c);
    my %allowed_roles = map { $_->{name} => undef } @$roles;
    $node_status = $c->model('Node')->availableStatus();

    $form_single = pfappserver::Form::Node->new(ctx => $c, status => $node_status, roles => $roles);
    $form_import = pfappserver::Form::Node::Create::Import->new(ctx => $c, roles => $roles);

    if (scalar(keys %{$c->request->params}) > 1) {
        # We consider the request parameters only if we have at least two entries.
        # This is the result of setuping jQuery in "no Ajax cache" mode. See admin/common.js.
        $params = $c->request->params;
    } else {
        $params = {};
    }
    $form_single->process(params => $params);

    if ($c->request->method eq 'POST') {
        # Create new nodes
        $type = $c->request->param('type');
        if ($type eq 'single') {
            if ($form_single->has_errors) {
                $status = HTTP_BAD_REQUEST;
                $message = $form_single->field_errors;
            }
            else {
                ($status, $message) = $c->model('Node')->create($form_single->value);
            }
        }
        elsif ($type eq 'import') {
            my $params = $c->request->params;
            $params->{nodes_file} = $c->req->upload('nodes_file');
            $form_import->process(params => $params);
            if ($form_import->has_errors) {
                $status = HTTP_BAD_REQUEST;
                $message = $form_import->field_errors;
            }
            else {
                my $filename = $form_import->value->{nodes_file}->tempname;
                my $data = $form_import->value;
                $data->{nodes_file_display_name} = $form_import->value->{nodes_file}->filename;

                ($status, $message) = $c->model('Node')->importCSV($filename, $data, $c->user, \%allowed_roles);
                if (is_success($status)) {
                    $message = $c->loc("[_1] nodes imported, [_2] skipped", $message->{count}, $message->{skipped});
                }
            }
        }
        else {
            $status = $STATUS::INTERNAL_SERVER_ERROR;
        }
        $self->audit_current_action($c, status => $status, create_type => $type);

        $c->response->status($status);
        $c->stash->{status} = $status;
        $c->stash->{status_msg} = $message; # TODO: localize error message
        $c->stash->{current_view} = 'JSON';
        # Since we are posting to an iframe if the content type is not plain text some browsers (IE 8/9) will try and download it
        $c->stash->{json_view_content_type} = 'text/plain';
    }
    else {
        # Initial display of the page
        $form_import->process();

        $c->stash->{form_single} = $form_single;
        $c->stash->{form_import} = $form_import;
    }
}

=head2 object

Node controller dispatcher

=cut

sub object :Chained('/') :PathPart('node') :CaptureArgs(1) {
    my ( $self, $c, $mac ) = @_;
    my $tenant_id = $c->req->param('tenant_id');
    if ($tenant_id) {
        pf::dal->set_tenant($tenant_id);
    }

    my ($status, $node_ref, $roles_ref);

    ($status, $node_ref) = $c->model('Node')->exists($mac);
    if ( is_error($status) ) {
        $c->response->status($status);
        $c->stash->{status_msg} = $node_ref;
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
    ($status, $roles_ref) = $c->model('Config::Roles')->listFromDB();
    if (is_success($status)) {
        $c->stash->{roles} = $roles_ref;
    }

    $c->stash(
        mac => $mac,
        tenant_id => $tenant_id,
    );
}

=head2 view

=cut

sub view :Chained('object') :PathPart('read') :Args(0) :AdminRole('NODES_READ') {
    my ($self, $c) = @_;

    my ($nodeStatus, $result);
    my ($form, $status);

    # Form initialization :
    # Retrieve node details and status
    our @tabs = qw(Location Violations);
    if (isenabled($Config{mse_tab}{enabled}) && admin_can([$c->user->roles], 'MSE_READ')) {
        push @tabs, 'MSE';
    }

    push @tabs, 'WMI', 'Option82', 'Rapid7';

    ($status, $result) = $c->model('Node')->view($c->stash->{mac});
    if (is_success($status)) {
        $c->stash->{node} = $result;
    }
    $c->stash->{switches} = $self->_get_switches_metadata($c);
    $nodeStatus = $c->model('Node')->availableStatus();
    $form = $c->form("Node",
        init_object => $c->stash->{node},
        status => $nodeStatus,
        roles => $c->stash->{roles}
    );
    $form->process();
    $c->stash({
        form => $form,
        tabs => \@tabs,
    });

#    my @now = localtime;
#    $c->stash->{now} = { date => POSIX::strftime("%Y-%m-%d", @now),
#                         time => POSIX::strftime("%H:%M", @now) };
}

=head2 update

=cut

sub update :Chained('object') :PathPart('update') :Args(0) :AdminRole('NODES_UPDATE') {
    my ( $self, $c ) = @_;
    my ( $status, $message, $result );

    $c->stash->{current_view} = 'JSON';

    if ( $c->request->params->{'multihost'} eq "yes" ) {
        $c->log->info("Doing multihost 'update' called with MAC '" . $c->stash->{mac} . "'");
        my @mac = pf::node::check_multihost($c->stash->{mac});
        foreach my $mac ( @mac ) {
            $c->log->info("Multihost 'update' for MAC '$mac'");
            $c->stash->{mac} = $mac;
            ( $status, $result ) = $self->_update($c);
            if ( is_error($status) ) {
                $c->response->status($status);
                $c->stash->{status_msg} = $result;
                return;
            }
        }
    } else {
        ( $status, $result ) = $self->_update($c);
    }

    $c->response->status($status);

    if (is_error($status)) {
        $c->stash->{status_msg} = $result; # TODO: localize error message
    }
}

=head2 _update

=cut

sub _update {
    my ( $self, $c ) = @_;
    my ( $status, $message );

    my ( $form, $nodeStatus );
    my $model = $c->model('Node');

    ( $status, my $result ) = $model->view($c->stash->{mac});
    if ( is_success($status) ) {
        if( $self->_is_role_allowed($c, $result->{category}) ) {
            $nodeStatus = $model->availableStatus();
            $form = $c->form("Node",
                init_object => $result,
                status => $nodeStatus,
                roles => $c->stash->{roles},
            );
            $form->process(
                params => {mac => $c->stash->{mac}, %{$c->request->params}},
            );
            if ( $form->has_errors ) {
                $status = HTTP_BAD_REQUEST;
                $result = $form->field_errors;
            }
            else {
                ( $status, $result ) = $c->model('Node')->update($c->stash->{mac}, $form->value);
                $self->audit_current_action($c, status => $status, mac => $c->stash->{mac});
            }
        }
        else {
            $status = HTTP_BAD_REQUEST;
            $result = "Do not have permission to modify node";
        }
    }

    return ( $status, $result );
}

=head2 delete

=cut

sub delete :Chained('object') :PathPart('delete') :Args(0) :AdminRole('NODES_DELETE') {
    my ( $self, $c ) = @_;

    my ($status, $message) = $c->model('Node')->delete($c->stash->{mac});
    $self->audit_current_action($c, status => $status, mac => $c->stash->{mac});
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $message; # TODO: localize error message
    }
    $c->stash->{current_view} = 'JSON';
}

=head2 reevaluate_access

Trigger the access reevaluation of the access of a node

=cut

sub reevaluate_access :Chained('object') :PathPart('reevaluate_access') :Args(0) :AdminRole('NODES_UPDATE') {
    my ( $self, $c ) = @_;
    my $mac = $c->stash->{mac};
    my ($status, $message) = $c->model('Node')->reevaluate($mac);
    $self->audit_current_action($c, status => $status, mac => $mac);
    if (is_error($status)) {
        $c->log->error("Cannot reevaluate access for $mac");
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $message; # TODO: localize error message
    $c->stash->{current_view} = 'JSON';
}

=head2 refresh_fingerbank_device

Refresh the Fingerbank detected device

=cut

sub refresh_fingerbank_device :Chained('object') :PathPart('refresh_fingerbank_device') :Args(0) :AdminRole('NODES_UPDATE') {
    my ( $self, $c ) = @_;

    my ($status, $message) = $c->model('Node')->refresh_fingerbank_device($c->stash->{mac});
    $self->audit_current_action($c, status => $status, mac => $c->stash->{mac});
    $c->response->status($status);
    $c->stash->{status_msg} = $message; # TODO: localize error message
    $c->stash->{current_view} = 'JSON';
}

=head2 restart_switchport

Restart the switchport for a device

=cut

sub restart_switchport :Chained('object') :PathPart('restart_switchport') :Args(0) :AdminRole('NODES_UPDATE') {
    my ( $self, $c ) = @_;
    my $mac = $c->stash->{mac};
    my ($status, $message) = $c->model('Node')->restartSwitchport($mac);
    $self->audit_current_action($c, status => $status, mac => $mac);
    if (is_error($status)) {
        $c->log->error("Cannot restart switch port for $mac");
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $message; # TODO: localize error message
    $c->stash->{current_view} = 'JSON';
}

=head2 violations

=cut

sub violations :Chained('object') :PathPart :Args(0) :AdminRole('NODES_READ') {
    my ($self, $c) = @_;
    my ($status, $result) = $c->model('Node')->violations($c->stash->{mac});
    if (is_success($status)) {
        $c->stash->{items} = $result->{'violations'};
        $c->stash->{multihost} = $result->{'multihost'};
        (undef, $result) = $c->model('Config::Violations')->readAll();
        my @violations = grep { $_->{id} ne 'defaults' } @$result; # remove defaults
        $c->stash->{violations} = \@violations;
    }
    else {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 runRapid7Scan

Run a Rapid7 scan on a node

=cut

sub runRapid7Scan :Chained('object') :PathPart('runRapid7Scan') :Args(1) :AdminRole('NODES_UPDATE') {
    my ( $self, $c, $id ) = @_;
    
    $c->stash->{current_view} = 'JSON';

    my $mac = $c->stash->{mac};

    my $scan = pf::Connection::ProfileFactory->instantiate($mac)->findScan($mac);
    if(ref($scan) ne "pf::scan::rapid7") {
        my $msg = "The scan engine for $mac is not a Rapid7 scan engine.";
        $c->log->error($msg);
        $c->response->status(HTTP_UNPROCESSABLE_ENTITY);
        $c->stash->{status_msg} = $msg;
    }

    $self->audit_current_action($c, mac => $mac, scan_id => $id);
    my $response = $scan->runScanTemplate("Manual scan from PacketFence", pf::ip4log::mac2ip($mac), $id);

    if($response->is_success) {
        $c->response->status(HTTP_OK);
        $c->stash->{status_msg} = "Successfully started scan.";
    }
    else {
        $c->response->status(HTTP_INTERNAL_SERVER_ERROR);
        $c->stash->{status_msg} = "Failed to start scan, check server side logs for details.";
    }

}

=head2 triggerViolation

=cut

sub triggerViolation :Chained('object') :PathPart('trigger') :Args(1) :AdminRole('NODES_UPDATE') {
    my ( $self, $c, $id ) = @_;

    my ( $status, $result ) = $c->model('Config::Violations')->hasId($id);
    if ( is_success($status) ) {
        ( $status, $result ) = $self->_triggerViolation($c, $id);
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $result;
    if (is_success($status)) {
        $c->forward('violations');
    }
    else {
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 triggerViolation_multihost

=cut

sub triggerViolation_multihost :Chained('object') :PathPart('trigger_multihost') :Args(1) :AdminRole('NODES_UPDATE') {
    my ( $self, $c, $id ) = @_;

    my ( $status, $result ) = $c->model('Config::Violations')->hasId($id);
    if ( is_success($status) ) {
        $c->log->info("Doing multihost 'triggerViolation' called with MAC '" . $c->stash->{mac} . "'");
        my @mac = pf::node::check_multihost($c->stash->{mac});
        foreach my $mac ( @mac ) {
            $c->log->info("Multihost 'triggerViolation' for MAC '$mac' with violation ID '$id'");
            $c->stash->{mac} = $mac;
            ( $status, $result ) = $self->_triggerViolation($c, $id);
            if ( is_error($status) ) {
                $c->stash->{current_view} = 'JSON';
                return;
            }
        }
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $result;
    if (is_success($status)) {
        $c->forward('violations');
    }
    else {
        $c->stash->{current_view} = 'JSON';
    }        
}

=head2 _triggerViolation

=cut

sub _triggerViolation {
    my ( $self, $c, $id ) = @_;

    my ( $status, $result );
    ( $status, $result ) = $c->model('Node')->addViolation($c->stash->{mac}, $id);
    $self->audit_current_action($c, status => $status, mac => $c->stash->{mac}, violation_id => $id);

    return ( $status, $result );
}

=head2 closeViolation

=cut

sub closeViolation :Path('close') :Args(1) :AdminRole('NODES_UPDATE') {
    my ($self, $c, $id) = @_;
    my ($status, $result) = $c->model('Node')->closeViolation($id);
    my @violation = violation_view($id);
    if (@violation) {
        $self->audit_current_action($c, status => $status, mac => $violation[0]->{mac});
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $result;
    $c->stash->{current_view} = 'JSON';
}

=head2 runViolation

=cut

sub runViolation :Path('run') :Args(1) :AdminRole('NODES_UPDATE') {
    my ($self, $c, $id) = @_;
    my ($status, $result) = $c->model('Node')->runViolation($id);
    my @violation = violation_view($id);
    if (@violation) {
        $self->audit_current_action($c, status => $status, mac => $violation[0]->{mac});
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $result;
    $c->stash->{current_view} = 'JSON';
}

=head2 tab_view

Tab View

=cut

sub tab_view :Chained('object') :PathPart :Args(1) :AdminRole('NODES_READ') {
    my ($self, $c, $tab_name) = @_;
    my $model = $c->model("Node::Tab::$tab_name");
    my ($status, $results) = $model->process_view($c);
    $c->response->status($status);
    $c->stash->{template} = "node/tab_${tab_name}_view.tt";
    $c->stash($results);
}

=head2 tab_process

Tab Process

=cut

sub tab_process :Chained('object') :PathPart :Args() :AdminRole('NODES_READ') {
    my ($self, $c, $tab_name, @args) = @_;
    my $model = $c->model("Node::Tab::$tab_name");
    my ($status, $results) = $model->process_tab($c, @args);
    $c->response->status($status);
    $c->stash->{template} = "node/tab_${tab_name}_process.tt";
    $c->stash($results);
}

=head2 bulk_apply_bypass_role

=cut

sub bulk_apply_bypass_role : Local : Args(1) :AdminRole('NODES_UPDATE') {
    my ( $self, $c, $role ) = @_;
    $c->stash->{current_view} = 'JSON';
    my ( $status, $status_msg );
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my @ids = $request->param('items');
        ($status, $status_msg) = $self->getModel($c)->bulkApplyBypassRole($role,@ids);
        $self->audit_current_action($c, status => $status, macs => \@ids);
    }
    else {
        $status = HTTP_BAD_REQUEST;
        $status_msg = "";
    }
    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg;
}

sub _get_switches_metadata : Private {
    my ($self,$c) = @_;
    my ($status, $result) = $c->model('Config::Switch')->readAll();
    if (is_success($status)) {
        my %switches = map { $_->{id} => { type => $_->{type},
                                           mode => $_->{mode},
                                           description => $_->{description} } } @$result;
        return \%switches;
    }
    return undef;
}

=head2 get_allowed_options

Get the allowed options for the user

=cut

sub get_allowed_options {
    my ($self, $c, $option) = @_;
    return admin_allowed_options([$c->user->roles], $option);
}

=head2 get_allowed_node_roles

Get the allowed node roles for the current user

=cut

sub get_allowed_node_roles {
    my ($self, $c) = @_;
    my %allowed_roles = map { $_ => undef } $self->get_allowed_options($c, 'allowed_node_roles');
    (undef, my $all_roles) = $c->model('Config::Roles')->listFromDB();
    return $all_roles if keys %allowed_roles == 0;
    return [ grep { exists $allowed_roles{$_->{name}} } @$all_roles ];
}

=head2 _is_role_allowed

=cut

sub _is_role_allowed {
    my ( $self, $c, $role ) = @_;
    my %allowed_node_roles = map { $_ => undef } $self->get_allowed_options( $c, 'allowed_node_roles' );
    return
        keys %allowed_node_roles == 0     ? $TRUE
      : (!defined $role || length($role) == 0) ? $TRUE
      : exists $allowed_node_roles{$role} ? $TRUE
      :                                     $FALSE;
}

=head1 AUTHOR

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

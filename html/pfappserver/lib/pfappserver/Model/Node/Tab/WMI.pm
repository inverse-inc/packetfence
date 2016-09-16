package pfappserver::Model::Node::Tab::WMI;

=head1 NAME

pfappserver::Model::Node::Tab::WMI -

=cut

=head1 DESCRIPTION

pfappserver::Model::Node::Tab::WMI

=cut

use strict;
use warnings;
use pf::config qw(%Config);
use pf::error qw(is_error is_success);
use pf::locationlog qw(locationlog_history_mac);
use base qw(pfappserver::Base::Model::Node::Tab);

=head2 process_view

Process view

=cut

sub process_view {
    my ($self, $c, @args) = @_;
    my $mac = $c->stash->{mac};
    my ($status, @scans);
    ($status, my $node) = $c->model("Node")->view($mac);
    my $scan_model = $c->model("Config::Scan");
    eval {
        my $profile = pf::Portal::ProfileFactory->instantiate($mac);
        foreach my $scan (split(/\s*,\s*/, $profile->{_scans})) {
            ($status, my $item) = $scan_model->read($scan);
            if (is_success($status)) {
                push @scans, $item;
            }
        }
    };
    if ($@) {
        $c->log->error($@);
        return ($STATUS::INTERNAL_SERVER_ERROR, {status_msg => "Error retrieving information for $mac"});
    }
    my $wmi_model = $c->model("Config::WMI");
    my @items;
    foreach my $scan ( @scans) {
        foreach my $rule_id (@{$scan->{wmi_rules} // []}) {
            ($status, my $rule) = $wmi_model->read($rule_id);
            if (is_success($status) && $rule->{on_tab}) {
                push @items, { scan_id => $scan->{id}, rule_id => $rule->{id} };
            }
        }
    }
    
 
    use Data::Dumper;
    $c->log->info(Dumper(\@items, \@scans, $node->{iplog}->{ip}));
    return ($STATUS::OK, {items => \@items, node => $node});
}

=head2 process_tab

Process tab

=cut

sub process_tab {
    my ($self, $c, $scan_id, $rule_id, $node, @args) = @_;
    
    use Data::Dumper;
    
    $self->parseWmi($c, $scan_id, $rule_id);
    #scanProcess();
    #my $host = $result->{iplog}->{ip};
    #foreach my $value ( keys %{$scan_config} ) {
    #    $scan_config->{'_' . $value} = $scan_config->{$value};
    #}
    #$scan_config->{_scanIp} = $host;
    
    return ($STATUS::OK);

}

=head2 parseWmi

parsing Wmi answer

=cut

sub parseWmi {
    my ($self, $c, $scan_id, $rule_id, $node) = @_;
    my $scan_model = $c->model("Config::Scan");
    my $wmi_model = $c->model("Config::WMI");
    my $scan = pf::scan::wmi::rules->new();
    my $scan_config = $scan_model->read($scan_id);
    my $rule_config = $wmi_model->read($rule_id);

    my $host = $node->{iplog}->{ip};
    use Data::Dumper;
    $c->log->info(Dumper($scan_config, $rule_config, $node, $host));
    #    my $rule_detail = $model->read($rule);
    #    my $config_rule = $rule_detail->[1];
    my $scan_result = $scan->runWmi($scan_config, $rule_config);
    $c->log->info(Dumper($scan_result));
    #    if ($scan_result =~ /0x80041010/ || !@$scan_result) {
    #        $rule->{item_exist} = 'No';
    #    }elsif ($scan_result =~ /TIMEOUT/ || $scan_result =~ /UNREACHABLE/) {
    #        $rule->{item_exist} = 'Request failed';
    #    }else {
    #        $rule->{item_exist} = 'Yes';
    #    }
    #    $rule->{scan_result} = $scan_result;
}

=head2 scanSecuritySoftware

Launch standard security scans

=cut

sub scanSecuritySoftware {
    my ($self, $c) = @_;

    my $scan_config = $c->stash->{scan_config};
    my $scan = pf::scan::wmi::rules->new();
    my $scan_exist = "200";#->$scan_exist;
    #my ($status, $result) = $c->model('Node')->view($c->stash->{mac});
    #if (is_success($status)) {
    #    $c->stash->{node} = $result;
    #}

    #my $profile = pf::Portal::ProfileFactory->instantiate($result->{mac});
    #my $mac = $c->stash->{mac};
    #my ($scan_exist, $scan_config);
    #eval {
    #    ($scan_exist, $scan_config) = $c->model('Config::Scan')->read($profile->{_scans});
    #};
    #if ($@) {
    #    $c->log->error($@);
    #    return ($STATUS::INTERNAL_SERVER_ERROR, {status_msg => "Error retrieving information for $mac"});
    #}
    #my $host = $result->{iplog}->{ip};
    #
    #foreach my $value ( keys %{$scan_config} ) {
    #    $scan_config->{'_' . $value} = $scan_config->{$value};
    #}
 
    #$scan_config->{_scanIp} = $host;


    my $rules = $self->parseWmi($c, $scan, $scan_config);
    use Data::Dumper;
    $c->log->info(Dumper($rules));

    if (is_success($scan_exist) && $rules) {
        $c->stash->{rules} = $rules;
    }else {
        $c->response->status($scan_exist);
        $c->stash->{status_msg} = $scan_config;
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 scanProcess

Try to scan the active processus on the client

=cut

sub scanProcess {#:Chained('object') :PathPart :Args(0) :AdminRole('WMI_READ') {
    my ($self, $c) = @_;

    my $scan_config = $c->stash->{scan_config};
    my $scan = $c->stash->{scan};

    my $config_process = $c->model('Config::WMI')->read('Process_Running');
    my $result_process = $scan->runWmi($scan_config, $config_process);
    if ($result_process =~ /0x80041010/) {
        $c->stash->{running_process} = 'No';
    }elsif ($result_process =~ /TIMEOUT/ || $result_process =~ /UNREACHABLE/) {
        $c->stash->{running_process} = 'Request failed';
    }else {
        $c->stash->{running_process} = $result_process;
    }
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

1;

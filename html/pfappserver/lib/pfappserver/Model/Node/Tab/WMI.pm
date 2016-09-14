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

=head2 process_tab

Process Tab

=cut

sub process_view {
    my ($self, $c, @args) = @_;

    my ($status, $result) = $c->model('Node')->view($c->stash->{mac});
    if (is_success($status)) {
        $c->stash->{node} = $result;
    }

    my ($scan, $scan_config, $scan_exist) = pfappserver::PacketFence::Controller::Node->wmiConfig($c, $result);

    return ($STATUS::OK, { items => \$result });
}

#=head2 wmiConfig
#
#Load the Wmi configuration matching the portal profile
#
#=cut
#
#sub wmiConfig {#:Chained('object') :PathPart :Args(0) :AdminRole('WMI_READ'){
#    my ($self, $c, $result) = @_;
#
#    my $scan = pf::scan::wmi::rules->new();
#    my $profile = pf::Portal::ProfileFactory->instantiate($result->{mac});
#    my ($scan_exist, $scan_config) = $c->model('Config::Scan')->read($profile->{_scans});
#
#    my $host = $result->{iplog}->{ip};
#    
#    foreach my $value ( keys %{$scan_config} ) {
#        $scan_config->{'_' . $value} = $scan_config->{$value};
#    }
# 
#    $scan_config->{_scanIp} = $host;
#    return $scan, $scan_config, $scan_exist;
#}
#
#=head2 parseWmiSecurity
#
#parsing Wmi Security Scan answer
#
#=cut
#
#sub parseWmiSecurity {#:Chained('object') :PathPart :Args(0) :AdminRole('WMI_READ'){
#    my ($self, $c, $scan, $scan_config) = @_;
#    my $rule_config = $c->model('Config::WMI')->readAll();
#    my @rules = grep {$_->{on_tab}} @$rule_config;
#    foreach my $rule (@rules) { 
#        my $config = $c->model('Config::WMI')->read($rule);
#        my $config_rule = $config->[1];
#        my $scan_result = $scan->runWmi($scan_config, $config_rule);
#        if ($scan_result =~ /0x80041010/ || !@$scan_result) {
#            $rule->{item_exist} = 'No';
#        }elsif ($scan_result =~ /TIMEOUT/ || $scan_result =~ /UNREACHABLE/) {
#            $rule->{item_exist} = 'Request failed';
#        }else {
#            $rule->{item_exist} = 'Yes';
#        }
#        $rule->{scan_result} = $scan_result;
#    }
#    return \@rules;
#}
#
#
#=head2 scanProcess
#
#Try to scan the active processus on the client
#
#=cut
#
#sub scanProcess {#:Chained('object') :PathPart :Args(0) :AdminRole('WMI_READ') {
#    my ($self, $c) = @_;
#
#    my ($status, $result) = $c->model('Node')->view($c->stash->{mac});
#
#    my ($scan, $scan_config) = wmiConfig($self, $c, $result);
#
#    my $config_process = $c->model('Config::WMI')->read('Process_Running');
#    my $result_process = $scan->runWmi($scan_config, $config_process);
#    if ($result_process =~ /0x80041010/) {
#        $c->stash->{running_process} = 'No';
#    }elsif ($result_process =~ /TIMEOUT/ || $result_process =~ /UNREACHABLE/) {
#        $c->stash->{running_process} = 'Request failed';
#    }else {
#        $c->stash->{running_process} = $result_process;
#    }
#}
#
#=head2 runScanWmi
#
#Lauch the WMI scan
#
#=cut
#
#sub runScanWmi {
#    my ($self, $c, $scan, $scan_config, $scan_exist) = @_;
#
#    my $rules = parseWmiSecurity($self, $c, $scan, $scan_config);
#
#    if (is_success($scan_exist) && $rules) {
#        $c->stash->{rules} = $rules;
#    }else {
#        $c->response->status($scan_exist);
#        $c->stash->{status_msg} = $scan_config;
#        $c->stash->{current_view} = 'JSON';
#    }
#
#}

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

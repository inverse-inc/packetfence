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

    my ($status, $result) = $c->model('Node')->view($c->stash->{mac});
    if (is_success($status)) {
        $c->stash->{node} = $result;
    }

    my $scan = pf::scan::wmi::rules->new();
    my $profile = pf::Portal::ProfileFactory->instantiate($result->{mac});
    my $mac = $c->stash->{mac};
    my ($scan_exist, $scan_config);
    eval {
        ($scan_exist, $scan_config) = $c->model('Config::Scan')->read($profile->{_scans});
    };
    if ($@) {
        $c->log->error($@);
        return ($STATUS::INTERNAL_SERVER_ERROR, {status_msg => "Error retrieving information for $mac"});
    }
    my $host = $result->{iplog}->{ip};
    
    foreach my $value ( keys %{$scan_config} ) {
        $scan_config->{'_' . $value} = $scan_config->{$value};
    }
 
    $scan_config->{_scanIp} = $host;
    $c->stash({
        scan => $scan,
        scan_exist => $scan_exist,
        scan_config => $scan_config,
        result => $result,
    });
    use Data::Dumper;
    $c->log->info(Dumper($scan));
    return ($STATUS::OK, {scan => $scan, scan_exist => $scan_exist, scan_config => $scan_config, result => $result});
}

=head2 process_tab

Process tab

=cut

sub process_tab {
    my ($self, $c, @args) = @_;
    #scanSecuritySoftware(); 
    #scanProcess();
    my $scan_config = $c->stash->{scan_config};
    my $scan_exist = $c->stash->{scan_exist};
    my $scan = $c->stash->{scan};

    use Data::Dumper;
    $c->log->info(Dumper($scan));
    my $rules = $self->parseWmi($c, $scan, $scan_config);
    $c->log->info(Dumper($rules));

    if (is_success($scan_exist) && $rules) {
        $c->stash->{rules} = $rules;
    }else {
        $c->response->status($scan_exist);
        $c->stash->{status_msg} = $scan_config;
        $c->stash->{current_view} = 'JSON';
    }

    return ($STATUS::OK, {rules => $rules})

}

=head2 parseWmi

parsing Wmi answer

=cut

sub parseWmi {#:Chained('object') :PathPart :Args(0) :AdminRole('WMI_READ'){
    my ($self, $c, $scan, $scan_config) = @_;
    my $rule_config = $c->model('Config::WMI')->readAll();
    my @rules = grep {$_->{on_tab}} @$rule_config;
    foreach my $rule (@rules) { 
        my $config = $c->model('Config::WMI')->read($rule);
        my $config_rule = $config->[1];
        my $scan_result = $scan->runWmi($scan_config, $config_rule);
        if ($scan_result =~ /0x80041010/ || !@$scan_result) {
            $rule->{item_exist} = 'No';
        }elsif ($scan_result =~ /TIMEOUT/ || $scan_result =~ /UNREACHABLE/) {
            $rule->{item_exist} = 'Request failed';
        }else {
            $rule->{item_exist} = 'Yes';
        }
        $rule->{scan_result} = $scan_result;
    }
    return \@rules;
}

#=head2 scanSecuritySoftware
#
#Launch standard security scans
#
#=cut
#
#sub scanSecuritySoftware {#:Chained('object') :PathPart :Args(0) :AdminRole('WMI_READ') {
#    my ($self, $c) = @_;
#
#    my $scan_config = $c->stash->{scan_config};
#    my $scan_exist = $c->stash->{scan_exist};
#    my $scan = $c->stash->{scan};
#
#    my $rules = parseWmi($self, $c, $scan, $scan_config);
#    use Data::Dumper;
#    $c->log->info(Dumper($rules));
#
#    if (is_success($scan_exist) && $rules) {
#        $c->stash->{rules} = $rules;
#    }else {
#        $c->response->status($scan_exist);
#        $c->stash->{status_msg} = $scan_config;
#        $c->stash->{current_view} = 'JSON';
#    }
#}

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

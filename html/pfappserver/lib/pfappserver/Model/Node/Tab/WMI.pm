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
use pf::constants::scan qw($WMI_NS_ERR);
use base qw(pfappserver::Base::Model::Node::Tab);

=head2 process_view

Process view

=cut

sub process_view {
    my ($self, $c, @args) = @_;
    my $mac = $c->stash->{mac};
    my ($status, @scans);
    ($status, my $node) = $c->model("Node")->view($mac);
    my $device_class = $node->{device_class};
    my $host_ip = $node->{iplog}->{ip};
    my $scan_model = $c->model("Config::Scan");
    eval {
        my $profile = pf::Connection::ProfileFactory->instantiate($mac);
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
        my $rules = $scan->{wmi_rules} // [];
        $rules = [$rules] unless ref($rules);
        foreach my $rule_id (@$rules) {
            ($status, my $rule) = $wmi_model->read($rule_id);
            if (is_success($status) && $rule->{on_tab}) {
                push @items, { scan_id => $scan->{id}, rule_id => $rule->{id} };
            }
        }
    }
    
 
    return ($STATUS::OK, {items => \@items, device_class => $device_class, host_ip => $host_ip});
}

=head2 process_tab

Process tab

=cut

sub process_tab {
    my ($self, $c, $scan_id, $rule_id, @args) = @_;
    
    my $rules = $self->parseWmi($c, $scan_id, $rule_id);

    if ($rules) {
        $c->stash->{rules} = $rules;
    }else {
        $c->stash->{current_view} = 'JSON';
    }

    return ($STATUS::OK, {rules => $rules});

}

=head2 parseWmi

parsing Wmi answer

=cut

sub parseWmi {
    my ($self, $c, $scan_id, $rule_id) = @_;
    my $scan_model = $c->model("Config::Scan");
    my $mac = $c->stash->{mac};
    my $wmi_model = $c->model("Config::WMI");
    my $scan = pf::scan::wmi::rules->new();
    my $scan_config = $scan_model->read($scan_id);
    my $rule_config = $wmi_model->read($rule_id);
    my ($status, $node) = $c->model("Node")->view($mac);

    my $host = $node->{iplog}->{ip};
    foreach my $value ( keys %{$scan_config} ) {
        $scan_config->{'_' . $value} = $scan_config->{$value};
    }
    $scan_config->{_scanIp} = $host;
    my $scan_result = $scan->runWmi($scan_config, $rule_config);
    if ($scan_result =~ /ACCESS_DENIED/) {
        $rule_config->{item_exist} = "Access denied";
    }elsif ($scan_result =~ /$WMI_NS_ERR/ || !$scan_result) {
        $rule_config->{item_exist} = 'No';
    }elsif ($scan_result =~ /TIMEOUT/ || $scan_result =~ /UNREACHABLE/) {
        $rule_config->{item_exist} = 'Request failed';
    }else {
        $rule_config->{item_exist} = 'Yes';
    }
    $rule_config->{scan_result} = $scan_result;
    return $rule_config;
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

package captiveportal::Base::Actions;

=head1 NAME

captiveportal::Base::Actions

=head1 DESCRIPTION

Actions for Dynamic Routing

=cut

use strict;
use warnings;
use base qw(Exporter);
our @EXPORT = qw(
    %AUTHENTICATION_ACTIONS
);

use pf::authentication;
use pf::config;
use pf::Authentication::constants;
use pf::util;
use pf::constants::realm;

our %AUTHENTICATION_ACTIONS = (
    set_role => sub { $_[0]->new_node_info->{category} = $_[1]; },
    set_unregdate => sub { $_[0]->new_node_info->{unregdate} = $_[1] },
    set_access_duration => sub { $_[0]->new_node_info->{unregdate} = pf::config::access_duration($_[1]) },
    unregdate_from_source => sub { $_[0]->new_node_info->{unregdate} = authentication_match_wrapper($_[0]->source->id, $_[0]->auth_source_params, $Actions::SET_UNREG_DATE, undef, $_[0]->session->{extra}); },
    role_from_source => sub { $_[0]->new_node_info->{category} = authentication_match_wrapper($_[0]->source->id, $_[0]->auth_source_params, $Actions::SET_ROLE, undef, $_[0]->session->{extra}); },
    no_action => sub {},
    set_time_balance => sub { $_[0]->new_node_info->{time_balance} = pf::util::normalize_time($_[1]) },
    set_bandwidth_balance => sub { $_[0]->new_node_info->{bandwidth_balance} = pf::util::unpretty_bandwidth($_[1]) },
    time_balance_from_source => sub { $_[0]->new_node_info->{time_balance} = pf::util::normalize_time(authentication_match_wrapper($_[0]->source->id, $_[0]->auth_source_params, $Actions::SET_TIME_BALANCE)); },
    bandwidth_balance_from_source => sub { $_[0]->new_node_info->{bandwidth_balance} = pf::util::unpretty_bandwidth(authentication_match_wrapper($_[0]->source->id, $_[0]->auth_source_params, $Actions::SET_BANDWIDTH_BALANCE)); },
    default_actions => \&execute_default_actions,
    on_failure => sub {},
    on_success => sub {},
    destination_url => sub {$_[0]->app->session->{destination_url} = $_[1];},
);

=head2 authentication_match_wrapper

A wrapper around pf::authentication::match to add the portal context in the parameters

=cut

sub authentication_match_wrapper {
    my (@all) = @_;
    $all[1]->{context} = $pf::constants::realm::PORTAL_CONTEXT,
    return pf::authentication::match(@all);
}

sub execute_default_actions {
    my ($self) = @_;
    my $default_actions = ref($self)->new(id => "dummy", app => $self->app, parent => $self)->actions;
    while(my ($action, $params) = each(%$default_actions)) {
        get_logger->debug("Executing action $action with params : ".join(',', @{$params}));
        $AUTHENTICATION_ACTIONS{$action}->($self, @{$params});
    }
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


package pfappserver::PacketFence::Controller::Config::Filters;

=head1 NAME

pfappserver::Controller::Configuration::Filters - Catalyst Controller

=head1 DESCRIPTION

Controller for Filters configuration.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::constants qw($TRUE);
use pf::config::cached;
use File::Slurp;
use pfconfig::manager;
use pf::ConfigStore::VlanFilters;
use pf::ConfigStore::RadiusFilters;
use pf::ConfigStore::ApacheFilters;

BEGIN {
    extends 'pfappserver::Base::Controller';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/filters', CaptureArgs => 1 },
        # Configure access rights
        index   => { AdminRole => 'FILTERS_READ' },
        view    => { AdminRole => 'FILTERS_READ' },
        update  => { AdminRole => 'FILTERS_UPDATE' },
    },
);

our %FILTERS_IDENTIFIERS = (
    VLAN_FILTERS => "vlan-filters",
    RADIUS_FILTERS => "radius-filters",
    APACHE_FILTERS => "apache-filters",
);

our %CONFIGSTORE_MAP = (
    $FILTERS_IDENTIFIERS{VLAN_FILTERS}   => pf::ConfigStore::VlanFilters->new,
    $FILTERS_IDENTIFIERS{RADIUS_FILTERS} => pf::ConfigStore::RadiusFilters->new,
    $FILTERS_IDENTIFIERS{APACHE_FILTERS} => pf::ConfigStore::ApacheFilters->new,
);

our %ENGINE_MAP = (
    $FILTERS_IDENTIFIERS{VLAN_FILTERS}   => "FilterEngine::VlanScopes",
    $FILTERS_IDENTIFIERS{RADIUS_FILTERS} => "FilterEngine::RadiusScopes",
    $FILTERS_IDENTIFIERS{APACHE_FILTERS} => $CONFIGSTORE_MAP{"apache-filters"}->pfconfigNamespace,
);

=head1 METHODS
=cut

sub view :Path :Args(1) {
    my ($self, $c, $name) = @_;
    $c->stash->{tab} = $name;
    $self->object($c, $name);
    $c->stash->{template} = "config/filters/index.tt";
    $c->stash->{content} = read_file($c->stash->{object}->configFile);
}

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    my $name = $FILTERS_IDENTIFIERS{VLAN_FILTERS};
    $c->forward("view", [$name]);
}

sub object {
    my ($self, $c, $id) = @_;
    $c->stash->{id} = $id;
    $c->stash->{object} = $CONFIGSTORE_MAP{$id};
}

sub update :Chained('object') :PathPart :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{current_view} = 'JSON';
    
    pf::util::safe_file_update($c->stash->{object}->configFile, $c->request->param('content')); 

    my $manager = pfconfig::manager->new;
    my $namespace = $manager->get_namespace($ENGINE_MAP{$c->stash->{id}});
    $namespace->build();
    if(defined($namespace->{errors}) && @{$namespace->{errors}} > 0){
        my @errors = map {$self->_clean_error($_)} @{$namespace->{errors}};
        $c->stash->{dont_localize_status_msg} = $TRUE;
        $c->stash->{status_msg} = "There are errors in the file, check server side logs for details : ".join(", ", @errors);
        $c->response->status(HTTP_BAD_REQUEST);
    }
    else {
        pf::config::cached::ReloadConfigs($TRUE);
        $manager->expire($c->stash->{object}->pfconfigNamespace);
        my ($success, $msg) = $c->stash->{object}->commitPfconfig();
        unless($success){
            $c->stash->{dont_localize_status_msg} = $TRUE;
            $c->stash->{status_msg} = "There was an error saving the filters : $msg";
            $c->response->status(HTTP_INTERNAL_SERVER_ERROR);
        }
        else {
            $c->stash->{status_msg} = "Successfully installed new rules.";
        }
    }



}

sub _clean_error {
    my ($self, $error) = @_;
    my $msg = $error;
    $msg =~ s/\n/ /g;
    $msg =~ s/\t//g;
    return $msg;
}

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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


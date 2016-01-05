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
#        list   => { AdminRole => 'FILTERS_READ' },
#        create => { AdminRole => 'FILTERS_CREATE' },
        update => { AdminRole => 'FILTERS_UPDATE' },
#        remove => { AdminRole => 'FILTERS_DELETE' },
    },
);

our %CONFIGSTORE_MAP = (
    "vlan-filters" => pf::ConfigStore::VlanFilters->new,
    "radius-filters" => pf::ConfigStore::RadiusFilters->new,
    "apache-filters" => pf::ConfigStore::ApacheFilters->new,
);

our %ENGINE_MAP = (
    "vlan-filters" => "FilterEngine::VlanScopes",
    "radius-filters" => "FilterEngine::RadiusScopes",
    "apache-filters" => $CONFIGSTORE_MAP{"apache-filters"}->pfconfigNamespace,
);

=head1 METHODS
=cut

sub index :Path :Args(1) {

    my ($self, $c, $name) = @_;
    $c->stash->{tab} = $name;
    $self->object($c, $name);
    $c->stash->{content} = read_file($c->stash->{object}->configFile);

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
        $c->stash->{status_msg} = "Successfully installed new rules.";
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


package pfappserver::PacketFence::Controller::Config::Filters;

=head1 NAME

pfappserver::Controller::Configuration::Filters

=head1 DESCRIPTION

Controller for Filters configuration.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::constants qw($TRUE);
use File::Slurp;
use pf::IniFiles;
use pf::constants::filters qw(%FILTERS_IDENTIFIERS %CONFIGSTORE_MAP %ENGINE_MAP);
use pfconfig::manager;

BEGIN {
    extends 'pfappserver::Base::Controller';
}

__PACKAGE__->config(
    action => {
        object => { Chained => '/', PathPart => 'config/filters', CaptureArgs => 1 },
        # Configure access rights
        index   => { AdminRole => 'FILTERS_READ' },
        view    => { AdminRole => 'FILTERS_READ' },
        update  => { AdminRole => 'FILTERS_UPDATE' },
    },
);

=head1 METHODS

=head2 view

View an engine configuration

=cut

sub view :Path :Args(1) {
    my ($self, $c, $name) = @_;
    $c->stash->{tab} = $name;
    $self->object($c, $name);
    $c->stash->{template} = "config/filters/index.tt";
    $c->stash->{content} = read_file($c->stash->{object}->configFile);
}

=head2 index

The index of the engines configuration

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    my $name = $FILTERS_IDENTIFIERS{VLAN_FILTERS};
    $c->forward("view", [$name]);
}

=head2 object

Build the current object (ConfigStore)

=cut

sub object {
    my ($self, $c, $id) = @_;
    $c->stash->{id} = $id;
    $c->stash->{object} = $CONFIGSTORE_MAP{$id};
}

=head2 update

Update a filters configuration

=cut

sub update :Chained('object') :PathPart :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{current_view} = 'JSON';
    my $content = $c->request->param('content');
    local $pf::IniFiles::PrettyName = $c->stash->{id};
    my $ini = pf::IniFiles->new(-file => \$content);
    if (!defined $ini) {
        $c->stash->{status_msg} = [ "There are errors in the file [_1]. Your file was not been saved.", join(", ", map { $self->_clean_error($_)} @pf::IniFiles::errors) ];
        $c->response->status(HTTP_BAD_REQUEST);
        return;
    }

    pf::util::safe_file_update($c->stash->{object}->configFile, $content);
    $self->audit_current_action($c, configfile => $c->stash->{object}->configFile );

    my $manager = pfconfig::manager->new;
    # Try to build the engine and look for any errors during the creation
    my $namespace = $manager->get_namespace($ENGINE_MAP{$c->stash->{id}});
    $namespace->build();
    if(defined($namespace->{errors}) && @{$namespace->{errors}} > 0){
        my @errors = map {$self->_clean_error("$_->{rule}> $_->{message}")} @{$namespace->{errors}};
        $c->stash->{status_msg} = [ "There are errors in the file, check server side logs for details : [_1]. Your file has been saved but the configuration has not been made active.", join(", ", @errors) ];
        $c->response->status(HTTP_BAD_REQUEST);
    }
    else {
        # Reload it in pfconfig and sync in cluster
        my ($success, $msg) = $c->stash->{object}->commitPfconfig();
        unless($success){
            $c->stash->{status_msg} = [ "There was an error saving the filters : [_1]. Your file has been saved but the configuration has not been made active.", $msg ];
            $c->response->status(HTTP_INTERNAL_SERVER_ERROR);
        }
        else {
            $c->stash->{status_msg} = "Successfully installed new rules.";
        }
    }
}

=head2 _clean_error

Cleanup the error messages coming from the filter engine object.

=cut

sub _clean_error {
    my ($self, $error) = @_;
    my $msg = $error;
    $msg =~ s/\n/ /g;
    $msg =~ s/\t//g;
    return $msg;
}

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;


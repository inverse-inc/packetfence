package pf::UnifiedApi::Controller::Config::AdminUiPlugins;

=head1 NAME

pf::UnifiedApi::Controller::Config::AdminUiPlugins -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::AdminUiPlugins

Configuration of the admin UI plugins. A plugin is a service owning its own
API (proxied by the api-frontend under /api/v1/plugins/<id>/) that describes
its admin UI section with a JSON manifest.

=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::AdminUiPlugins';
has 'form_class' => 'pfappserver::Form::Config::AdminUiPlugin';
has 'primary_key' => 'admin_ui_plugin_id';

use pf::ConfigStore;
use pf::ConfigStore::AdminUiPlugins;
use pfappserver::Form::Config::AdminUiPlugin;
use pf::config::cluster;
use pf::file_paths qw($conf_dir);
use pf::util qw(isenabled);
use File::Spec::Functions qw(catfile);
use JSON::MaybeXS qw(decode_json);

=head2 enabled

List the enabled plugins with what the admin UI needs to load them

=cut

sub enabled {
    my ($self) = @_;
    my $plugins = $self->config_store->readAll('id');
    my @items;
    for my $plugin (sort { $a->{id} cmp $b->{id} } @$plugins) {
        next unless isenabled($plugin->{enabled} // 'enabled');
        my $item = {
            id          => $plugin->{id},
            description => $plugin->{description},
            acl         => $plugin->{acl} || 'SYSTEM',
            replaces    => $plugin->{replaces},
            api         => "plugins/$plugin->{id}",
            manifest    => undef,
        };
        my $manifest = $plugin->{manifest};
        if (defined $manifest && $manifest ne '') {
            $item->{manifest} = eval { decode_json($manifest) };
            if ($@ || ref($item->{manifest}) ne 'HASH') {
                $self->log->error("Invalid manifest for admin UI plugin $plugin->{id}");
                $item->{manifest} = undef;
                $item->{error} = 'Invalid manifest';
            }
        }
        push @items, $item;
    }

    return $self->render(json => { items => \@items }, status => 200);
}

=head2 commit_files

Commit configuration files written by a plugin: increment the configuration
version, expire their pfconfig namespaces and synchronize the cluster.

Only the files declared in the plugin config_files can be committed.

=cut

sub commit_files {
    my ($self) = @_;
    my $plugin = $self->item_from_store;
    if (!$plugin) {
        return $self->render_error(404, "Item (" . $self->id . ") not found");
    }

    my %declared = map {
        my ($path, $namespace) = split(/:/, $_, 2);
        ($path => $namespace)
    } @{ $plugin->{config_files} // [] };

    my $files;
    if (length($self->req->body // '')) {
        my ($error, $data) = $self->get_json;
        if (defined $error) {
            return $self->render_error(400, "Bad Request : $error");
        }
        $files = $data->{files};
    }

    $files //= [ sort keys %declared ];
    if (ref($files) ne 'ARRAY' || !@$files) {
        return $self->render_error(422, "No configuration file to commit");
    }

    my @errors = map { { field => 'files', message => "$_ is not a configuration file of the plugin" } } grep { !exists $declared{$_} } @$files;
    if (@errors) {
        return $self->render_error(422, "Unknown configuration files", \@errors);
    }

    if (!pf::config::cluster::increment_config_version()) {
        return $self->render_error(500, "Can't increment configuration version.");
    }

    for my $file (@$files) {
        my $cs = pf::ConfigStore->new(
            configFile        => catfile($conf_dir, $file),
            pfconfigNamespace => $declared{$file},
        );
        my ($result, $error) = $cs->commitPfconfig;
        if (!$result) {
            return $self->render_error(500, "Unable to commit $file: " . ($error // 'unknown error'));
        }
    }

    return $self->render(json => { message => "Committed", files => $files }, status => 200);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

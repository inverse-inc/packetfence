package pf::ConfigStore::Authentication;

=head1 NAME

pf::ConfigStore::Authentication

=cut

=head1 DESCRIPTION

pf::ConfigStore::Authentication

=cut

use Moo;
use namespace::autoclean;
use pf::authentication;
use pf::file_paths;
use HTTP::Status qw(:constants is_error is_success);
use pf::authentication;
use pf::log;
use pfconfig::cached_hash;
use List::Util qw(first);
use List::MoreUtils qw(none any);


our $cached_authentication_config;
our @auth_sources;
our %auth_lookup;

extends 'pf::ConfigStore';

readAuthenticationConfigFile();
setModuleSources();

=head1 METHODS

=head2 _buildCachedConfig

=cut

sub _buildCachedConfig { $cached_authentication_config };

sub configFile { $authentication_config_file }

sub pfconfigNamespace {'config::Authentication'}

before rewriteConfig => sub {
    my ($self) = @_;
    $self->cachedConfig->ReorderByGroup();
};

sub readAuthenticationConfigFile {
    unless ($cached_authentication_config) {
        $cached_authentication_config = pf::config::cached->new (
            -file => $authentication_config_file,
            -oncachereload => [
              on_cache_authentication_reload => sub {setModuleSources()}
        ] );
    } else {
        $cached_authentication_config->ReadConfig();
    }
}

sub setModuleSources {
    @auth_sources = sub { return @pf::authentication::authentication_sources }->();
    %auth_lookup = map { $_->id => $_ } grep { defined $_ } @auth_sources;
}

sub getSource {
    my ($id) = @_;;
    return unless defined $id && exists $auth_lookup{$id};

    return $auth_lookup{$id};
}

=head2 deleteSource

Delete an authentication source along its rules. Returns the number of source(s)
deleted.

=cut

sub deleteSource {
    my $id = shift;
    my $logger = get_logger;

    my %Profiles_Config;
    tie %Profiles_Config, 'pfconfig::cached_hash', 'config::Profiles';

    my $result = 0;
    if (none { any {$_ eq $id} @{$_->{sources}} } values %Profiles_Config) {
        for (my $i = 0; $i < scalar(@auth_sources); $i++) {
            my $source = $auth_sources[$i];
            if ($source->{id} eq $id) {
                splice(@auth_sources, $i, 1);
                $result = 1;
                last;
            }
        }
    }
    return $result;
}

=head2 writeAuthenticationConfigFile

Write the configuration file to disk

=cut

sub writeAuthenticationConfigFile {
    my ($self) = @_;
    my $logger = get_logger;
    my $cached_authentication_config = $self->cachedConfig;
    # Remove deleted sections
    my %new_sources = map { $_->id => undef } @auth_sources;
    foreach my $id ( grep { !exists $new_sources{$_} } $cached_authentication_config->Sections) {
        $cached_authentication_config->DeleteSection($id);
    }
    tie(my %cfg,$cached_authentication_config);

    # Update existing sections and create new ones
    foreach my $source ( @auth_sources ) {
        $logger->debug("Writing source " . $source->id . " (" . ref($source)->meta->name . ")");
        $cfg{$source->{id}} = {};
        $cfg{$source->{id}}{description} = $source->{'description'};

        for my $attr ( $source->meta->get_all_attributes ) {
            $attr = $attr->name;
            # Don't write static attributes (see pfappserver::Model::Authentication::Source::update)
            next if (grep { $_ eq $attr } qw[id rules unique class]);
            next unless ($source->{$attr});
            my $value = $source->{$attr};
            if (ref($value)) {
                $value = join(',', @$value);
            }
            $cfg{$source->{id}}{$attr} = $value;
        }

        # We flush rules, including conditions and actions.
        foreach my $rule ( @{$source->{'rules'}} ) {
            my $rule_id = $source->{'id'} . " rule " . $rule->{'id'};
            $logger->info("processing rule $rule_id");

            # Since 'description' is defined in the parent section, set the paramater through the object
            # for proper cfgtialization
            $cached_authentication_config->newval($rule_id, 'description', $rule->{'description'});
            $cfg{$rule_id}{match} = $rule->{'match'};

            my $index = 0;
            foreach my $action ( @{$rule->{'actions'}} ) {
                my $action_id = 'action' . $index;
                if (defined $action->{'value'}) {
                    $cfg{$rule_id}{$action_id} = $action->{'type'} . '=' . $action->{'value'};
                } else {
                    $cfg{$rule_id}{$action_id} = $action->{'type'};
                }
                $index++;
            }

            $index = 0;
            foreach my $condition ( @{$rule->{'conditions'}} ) {
                my $condition_id = 'condition' . $index;
                $cfg{$rule_id}{$condition_id} = $condition->{'attribute'} . ',' . $condition->{'operator'} . ',' . $condition->{'value'};
                $index++;
            }
        }
    }
    $cached_authentication_config->ReorderByGroup();
    my $result;
    $logger->info("doing the authentication write in the configstore");
    eval {
        $result = $cached_authentication_config->RewriteConfig();
    };
    $logger->error("Failed with : $@") if $@;
    unless($result) {
        $cached_authentication_config->Rollback();
        $logger->error("Error writing authentication configuration");
        die "Error writing authentication configuration\n";
    }

    # we signal pfconfig that we changed
    $self->commitPfconfig;
}

__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


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

1;


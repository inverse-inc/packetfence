package pf::authentication;

=head1 NAME

pf::authentication

=head1 DESCRIPTION

=over

=cut

use strict;
use warnings;

use Log::Log4perl qw(get_logger);

use pf::config;
use pf::config::cached;

use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::Authentication::Condition;
use pf::Authentication::Rule;
use pf::Authentication::Source;

use Module::Pluggable
  'search_path' => [qw(pf::Authentication::Source)],
  'sub_name'    => 'sources',
  'require'     => 1,
  ;

use List::Util qw(first);
use List::MoreUtils qw(none any);
use pf::util;

# The results...
#
# name=Foo Bar
# type=ldap
# ...
# rules= @( { actions => @actions(), conditions =>@conditions() },  { ... }, ... )
#
# NOTES:  a- sources are ordered
#         b- rules are ordered, as well as actions and conditions they contain
#
#
our @authentication_sources = ();
our %authentication_lookup;
our $cached_authentication_config;
our %guest_self_registration;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT =
      qw(
            @authentication_sources
            availableAuthenticationSourceTypes
            newAuthenticationSource
            getAuthenticationSource
            getAllAuthenticationSources
            deleteAuthenticationSource
            writeAuthenticationConfigFile
            %guest_self_registration
       );
    @EXPORT_OK =
      qw(
            authenticate
            match
            username_from_email
       );

}

our @SOURCES = __PACKAGE__->sources();

our %TYPE_TO_SOURCE = map { lc($_->meta->get_attribute('type')->default) => $_ } @SOURCES;

our $logger = get_logger();


readAuthenticationConfigFile();

=item availableAuthenticationSourceTypes

Return the list of source types, as defined in each of the class.

Can limit the sources to a specific class ('internal' or 'external').

=cut

sub availableAuthenticationSourceTypes {
    my $class = shift;

    my @types;
    foreach my $module (values %TYPE_TO_SOURCE) {
        next if ($module->meta->get_attribute('type')->default eq 'SQL');
        if (!defined $class || $module->meta->find_attribute_by_name('class')->default eq $class) {
            push(@types, $module->meta->get_attribute('type')->default);
        }
    }

    return \@types;
}

=item newAuthenticationSource

Returns an instance of pf::Authentication::Source::* for the given type

=cut

sub newAuthenticationSource {
    my ($type, $source_id, $attrs) = @_;

    my $source;
    $type = lc($type);
    if (exists $TYPE_TO_SOURCE{$type}) {
        my $source_module = $TYPE_TO_SOURCE{$type};
        $source = $source_module->new({ id => $source_id, %{$attrs} });
    }

    return $source;
}

=item readAuthenticationConfigFile

Populate @authentication_sources with object representations of the configuration file

=cut

sub readAuthenticationConfigFile {

    unless ($cached_authentication_config) {
        $cached_authentication_config = pf::config::cached->new (
            -file => $authentication_config_file,
            -onfilereload => [ reload_authentication_config => sub {
                @authentication_sources = ();
                %authentication_lookup = ();
                my ($config,$name) = @_;
                my %cfg;
                $config->toHash(\%cfg);
                foreach my $source_id ( $config->Sections() ) {

                    # We skip groups from our ini files
                    if ($source_id =~ m/\s/) {
                      next;
                    }

                    # Keep aside the source type
                    my $type = $config->val($source_id, "type");
                    delete $cfg{$source_id}{type};

                    # Instantiate the source object
                    my $current_source = newAuthenticationSource($type, $source_id, $cfg{$source_id});

                    # Parse rules
                    foreach my $rule_id ( $config->GroupMembers($source_id) ) {

                        my ($id) = $rule_id =~ m/$source_id rule (\S+)$/;
                        my $current_rule = pf::Authentication::Rule->new({match => $Rules::ANY, id => $id});

                        foreach my $parameter ( $config->Parameters($rule_id) ) {
                            if ($parameter =~ m/condition(\d+)/) {
                                #print "Condition $1: " . $config->val($rule, $parameter) . "\n";
                                my ($attribute, $operator, $value) = split(',', $config->val($rule_id, $parameter), 3);

                                $current_rule->add_condition( pf::Authentication::Condition->new({attribute => $attribute,
                                                                                                  operator => $operator,
                                                                                                  value => $value}) );
                            } elsif ($parameter =~ m/action(\d+)/) {
                                #print "Action: $1" . $config->val($rule_id, $parameter) . "\n";
                                my ($type, $value) = split('=', $config->val($rule_id, $parameter), 2);

                                if (defined $value) {
                                    $current_rule->add_action( pf::Authentication::Action->new({type => $type,
                                                                                                value => $value}) );
                                } else {
                                    $current_rule->add_action( pf::Authentication::Action->new({type => $type}) );
                                }

                            } elsif ($parameter =~ m/match/) {
                                $current_rule->{'match'} = $config->val($rule_id, $parameter);
                            } elsif ($parameter =~ m/description/) {
                                $current_rule->{'description'} = $config->val($rule_id, $parameter);
                            }
                        }

                        $current_source->add_rule($current_rule);
                    }
                    push(@authentication_sources, $current_source);
                    $authentication_lookup{$source_id} = $current_source;
                }
                $config->cacheForData->set("authentication_sources",\@authentication_sources);
            }],
            -oncachereload => [
                on_cache_authentication_reload => sub {
                    my ($config, $name) = @_;
                    my $authentication_sources_ref = $config->fromCacheForDataUntainted("authentication_sources");
                    if( defined($authentication_sources_ref) ) {
                        @authentication_sources = @$authentication_sources_ref;
                        %authentication_lookup = map { $_->id => $_ } grep { defined $_ } @authentication_sources;
                    } else {
                        $config->_callFileReloadCallbacks();
                    }
                },
            ],
            -onpostreload => [
                on_post_authentication_reload => sub {
                    update_profiles_guest_modes($cached_profiles_config,"update_profiles_guest_modes");
                }
            ],
        );
        $cached_profiles_config->addPostReloadCallbacks(update_profiles_guest_modes => \&update_profiles_guest_modes);

    } else {
        $cached_authentication_config->ReadConfig();
    }
}


sub update_profiles_guest_modes {
    my ($config,$name) = @_;
    %guest_self_registration = ();
    while (my ($id,$profile) = each %Profiles_Config) {
        my $guest_modes = _guest_modes_from_sources($profile->{sources});
        $profile->{guest_modes} = $guest_modes;
        _set_guest_self_registration($guest_modes);
    }
}

sub _set_guest_self_registration {
    my ($modes) = @_;
    for my $mode (
                  $SELFREG_MODE_EMAIL,
                  $SELFREG_MODE_SMS,
                  $SELFREG_MODE_SPONSOR,
                  $SELFREG_MODE_GOOGLE,
                  $SELFREG_MODE_FACEBOOK,
                  $SELFREG_MODE_GITHUB,
                 ) {
        $guest_self_registration{$mode} = $TRUE
          if is_in_list($mode, $modes);
    }
}

sub _guest_modes_from_sources {
    my ($sources) = @_;
    $sources ||= [];
    my %is_in = map {$_ => undef } @$sources;
    return join(',', map { lc($_->type)} grep { exists $is_in{$_->id} && $_->class eq 'external'} @authentication_sources);
}

=item writeAuthenticationConfigFile

Write the configuration file to disk

=cut

sub writeAuthenticationConfigFile {
    # Remove deleted sections
    my %new_sources = map { $_->id => undef } @authentication_sources;
    foreach my $id ( grep { !exists $new_sources{$_} } $cached_authentication_config->Sections) {
        $cached_authentication_config->DeleteSection($id);
    }
    tie(my %cfg,$cached_authentication_config);

    # Update existing sections and create new ones
    foreach my $source ( @authentication_sources ) {
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
    eval {
        $result = $cached_authentication_config->RewriteConfig();
    };
    unless($result) {
        $cached_authentication_config->Rollback();
        die "Error writing authentication configuration\n";
    }
}

=item getAuthenticationSource

Return an instance of pf::Authentication::Source::* for the given id

=cut

sub getAuthenticationSource {
    my $id = shift;
    if (exists $authentication_lookup{$id}) {
        return $authentication_lookup{$id};
    }
    return undef;
}

=item getAllAuthenticationSources

Return instances of pf::Authentication::Source for all defined sources

=cut

sub getAllAuthenticationSources { return \@authentication_sources }

=item getInternalAuthenticationSources

Return instances of pf::Authentication::Source for internal sources

=cut

sub getInternalAuthenticationSources {
    my @internal = grep { $_->{'class'} eq 'internal' } @authentication_sources;
    return \@internal;
}

=item deleteAuthenticationSource

Delete an authentication source along its rules. Returns the number of source(s)
deleted.

=cut

sub deleteAuthenticationSource {
    my $id = shift;

    my $result = 0;
    if (none { any {$_ eq $id} @{$_->{sources}} } values %Profiles_Config) {
        for (my $i = 0; $i < scalar(@authentication_sources); $i++) {
            my $source = $authentication_sources[$i];
            if ($source->{id} eq $id) {
                splice(@authentication_sources, $i, 1);
                $result = 1;
                last;
            }
        }
    }
    return $result;
}

# =head2 source_for_user

# =cut
# sub source_for_user {
#   my $username = shift;

#   foreach my $current_source ( @authentication_sources ) {
#     my $type = $current_source->{'type'};

#     if ($type eq "ad" || $type eq "ldap") {
#       my $result = match_in_ldap_source( $current_source, $username, 0 );

#       if (defined $result) {
#       #print "Found user in $current_source->{'id'}\n";
#       return $current_source;
#       }
#     }
#     # We must be careful here, to only check for users that can authenticate
#     # using the local SQL backend. We don't want to look for "persons", coming
#     # from other authentication sources.
#     elsif ($type eq "sql") {

#     }
#   }

#   return undef;
# }

=item authenticate

Authenticate a user given an optional list of authentication sources. If no source is specified, all defined
authentication sources are used.

=cut

sub authenticate {
    my ($username, $password, @sources) = @_;

    unless (@sources) {
        @sources = grep { $_->class ne 'exclusive'  } @authentication_sources;
    }

    $logger->debug(sub {"Authenticating '$username' from source(s) ".join(', ', map { $_->id } @sources) });

    foreach my $current_source (@sources) {
        my ($result, $message);
        $logger->trace("Trying to authenticate '$username' with source '".$current_source->id."'");
        eval {
            ($result, $message) = $current_source->authenticate($username, $password);
        };
        # First match wins!
        if ($result) {
            $logger->info("Authentication successful for $username in source ".$current_source->id." (".$current_source->type.")");
            return ($result, $message, $current_source->id);
        }
    }

    $logger->trace("Authentication failed for '$username' for all ".scalar(@sources)." sources");
    return ($FALSE, 'Wrong username or password.');
}

=item match

This method tries to match a set of params in one or multiple sources.

If action is undef, all actions will be returned.
If action is set, it will return the value of the action immediately.

=cut

sub match {
    my ($source_id, $params, $action) = @_;
    my ($actions, @sources);

    $logger->debug("Match called with parameters ".join(", ", map { "$_ => $params->{$_}" } keys %$params));

    if (ref($source_id) eq 'ARRAY') {
        @sources = @{$source_id};
    } else {
        my $source = getAuthenticationSource($source_id);
        if (defined $source) {
            @sources = ($source);
        }
    }
    my $source = first { defined ($actions = $_->match($params)) } @sources;

    if (defined $action && defined $actions) {
        my $found_action = first { $_->type eq $action } @{$actions};
        if (defined $found_action) {
            $logger->debug("[".$source->id."] Returning '".$found_action->value."' for action $action for username ".$params->{'username'});
            return $found_action->value
        }
        $logger->debug("[".$source->id."] Params don't match rules for action $action for parameters ".join(", ", map { "$_ => $params->{$_}" } keys %$params));
        return undef;
    }

    if (defined $action) {
        $logger->debug("No source matches action $action");
    } elsif (defined $source) {
        $actions ||= [];
        $logger->debug("[".$source->id."] Returning actions ".join(', ', map { $_->type." = ".$_->value } @$actions ));
    }

    return $actions;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

package pf::authentication;

=head1 NAME

pf::authentication

=head1 DESCRIPTION

=over

=cut

use strict;
use warnings;

use pf::log;

use pf::constants;
use pf::config;
use pf::config::util;

use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::Authentication::Condition;
use pf::Authentication::Rule;
use pf::Authentication::Source;
use pf::Authentication::constants qw($LOGIN_SUCCESS $LOGIN_FAILURE $LOGIN_CHALLENGE);
use pf::constants::authentication::messages;

use Module::Pluggable
  'search_path' => [qw(pf::Authentication::Source)],
  'sub_name'    => 'sources',
  'require'     => 1,
  'inner'       => 0,
  ;

use Clone qw(clone);
use List::Util qw(first);
use List::MoreUtils qw(none any all);
use pf::util;
use pfconfig::cached_array;
use pfconfig::cached_hash;
use pf::StatsD::Timer;
use pf::util::statsd qw(called);

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
our @authentication_sources;
tie @authentication_sources, 'pfconfig::cached_array', 'resource::authentication_sources';
our %authentication_lookup;
tie %authentication_lookup, 'pfconfig::cached_hash', 'resource::authentication_lookup';
our %guest_self_registration;
tie %guest_self_registration, 'pfconfig::cached_hash', 'resource::guest_self_registration';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
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
            getAuthenticationClassByType
            %guest_self_registration
       );
}

our @SOURCES = __PACKAGE__->sources();

our %TYPE_TO_SOURCE = map { lc($_->meta->get_attribute('type')->default) => $_ } @SOURCES;

our %TYPE_TO_CLASS = map { lc($_->meta->get_attribute('type')->default) => lc($_->meta->find_attribute_by_name('class')->default) } @SOURCES;

our $logger = get_logger();

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

=item getAuthenticationSource

Return an instance of pf::Authentication::Source::* for the given id

=cut

sub getAuthenticationSource {
    my $id = shift;
    return unless defined $id && exists $authentication_lookup{$id};

    return $authentication_lookup{$id};
}

=item getAllAuthenticationSources

Return instances of pf::Authentication::Source for all defined sources

=cut

sub getAllAuthenticationSources { return \@authentication_sources }

=item getInternalAuthenticationSources

Return instances of pf::Authentication::Source for internal sources

=cut

sub getInternalAuthenticationSources {
    my @sources = grep { $_->{'class'} eq 'internal' } @authentication_sources;
    return \@sources;
}

=item getExternalAuthenticationSources

Return instances of pf::Authentication::Source for external sources

=cut

sub getExternalAuthenticationSources {
    my @sources = grep { $_->{'class'} eq 'external' } @authentication_sources;
    return \@sources;
}

=item getAuthenticationSourcesByType

Return instances of pf::Authentication::Source for a given type

=cut

sub getAuthenticationSourcesByType {
    my ( $type ) = @_;
    my @sources = grep { $_->{'type'} eq $type } @authentication_sources;
    return \@sources;
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
    my ( $params, @sources ) = @_;

    my $username = $params->{'username'};
    my $password = $params->{'password'};

    #TODO: evaluate if we want to die or have another behavior
    my $context = $params->{'context'} // die "No authentication context provided";
    
    ($username, undef) = pf::config::util::strip_username_if_needed($username, $context);

    # If no source(s) provided, all 'internal' configured sources are used
    unless (@sources) {
        @sources = @{pf::authentication::getInternalAuthenticationSources()};
    }
    my $display_username = (defined $username) ? $username : "(anonymous)";

    # If a rule class is defined, we filter out authentication sources rules that doesn't match it
    if ( defined($params->{'rule_class'}) ) {
        my $cloned_sources = clone(\@sources);
        @sources = ();
        foreach my $source ( @$cloned_sources ) {
            my @rules = ();
            foreach my $rule ( @{ $source->{'rules'} } ) {
                push (@rules, $rule) if $rule->{'class'} eq $params->{'rule_class'};
            }
            if ( @rules ) {
                @{$source->{'rules'}} = ();
                push (@{$source->{'rules'}}, @rules);
            }
            push (@sources, $source);
        }
    }

    $logger->debug(sub {"Authenticating '$display_username' from source(s) ".join(', ', map { $_->id } @sources) });

    my $message;
    foreach my $current_source (@sources) {
        my ($result, $extra);
        $logger->trace("Trying to authenticate '$display_username' with source '".$current_source->id."'");
        eval {
            ($result, $message, $extra) = $current_source->authenticate($username, $password);
        };
        # First match wins!
        if ($result) {
            $logger->info("Authentication successful for $display_username in source ".$current_source->id." (".$current_source->type.")");
            return ($result, $message, $current_source->id, $extra);
        }
    }

    $logger->trace("Authentication failed for '$display_username' for all ".scalar(@sources)." sources");
    return ($FALSE, $message ? $message : $AUTH_FAIL_MSG);
}

=item match

This method tries to match a set of params in one or multiple sources.

If action is undef, all actions will be returned.
If action is set, it will return the value of the action immediately.
If source_id_ref is defined then it will be set to the matching source_id

=cut

our %ACTION_VALUE_FILTERS = (
    $Actions::SET_ACCESS_DURATION => \&pf::config::access_duration,
    $Actions::SET_UNREG_DATE => \&pf::config::dynamic_unreg_date,
);

sub match {
    my $timer = pf::StatsD::Timer->new();
    my ($source_id, $params, $action, $source_id_ref, $extra) = @_;
    my ($actions, @sources);
    $logger->debug( sub { "Match called with parameters " . join(", ", map { "$_ => " . ($params->{$_} // "undef") } keys %$params) });
    if( defined $action && !exists $Actions::ALLOWED_ACTIONS{$action}) {
        $logger->warn("Calling match with an invalid action of type '$action'");
        return undef;
    }

    #TODO: evaluate if we want to die or have another behavior
    my $context = $params->{'context'} // die "No authentication context provided";

    ($params->{'username'}, undef) = pf::config::util::strip_username_if_needed($params->{'username'}, $context);
    
    # Calling 'match' with empty/invalid rule class. Using default
    if ( (!defined($params->{'rule_class'})) || (!exists($Rules::CLASSES{$params->{'rule_class'}})) ) {
        $params->{'rule_class'} = pf::Authentication::Rule->meta->get_attribute('class')->default;
        $logger->warn("Calling match with empty/invalid rule class. Defaulting to '" . $params->{'rule_class'} . "'");
    }

    if (ref($source_id) eq 'ARRAY') {
        @sources = @{$source_id};
    } else {
        my $source = getAuthenticationSource($source_id);
        if (defined $source) {
            @sources = ($source);
        }
    }
    my $allowed_actions;
    if (defined $action && exists $Actions::ALLOWED_ACTIONS{$action}) {
        $allowed_actions = $Actions::ALLOWED_ACTIONS{$action};
    }
    $logger->info("Using sources ".join(', ', (map {$_->id} @sources))." for matching");

    foreach my $source (@sources) {
        my $rule = $source->match($params, $action, $extra);
        unless (defined $rule) {
            $logger->trace(sub {"Skipped " . $source->id });
            next;
        }
        $actions = $rule->{actions};
        if (defined $allowed_actions) {

            # Return the value only if the action matches
            my $found_action = first {exists $allowed_actions->{$_->type} && $allowed_actions->{$_->type}} @{$actions};
            if (defined $found_action) {
                $logger->debug(
                    sub {
                        "[" . $source->id . "] Returning '"
                          . ( $found_action->value // "undef" )
                          . "' for action '" . ( $action // "undef" )
                          . "' for username " . ( $params->{'username'} // "undef" )
                    }
                );
                $$source_id_ref = $source->id if defined $source_id_ref && ref $source_id_ref eq 'SCALAR';
                my $value = $found_action->value;
                my $type  = $found_action->type;
                $value = $ACTION_VALUE_FILTERS{$type}->($value) if exists $ACTION_VALUE_FILTERS{$type};
                return $value;
            }

            #Setting action to undef to avoid the wrong actions to be returned
            $actions = undef;
            $logger->debug( sub { "[" . $source->id . "] Params don't match rules for action $action for parameters " . join(", ", map {"$_ => $params->{$_}"} keys %$params) });
            next;
        }
        #Store the source id
        $$source_id_ref = $source->id if defined $source_id_ref && ref $source_id_ref eq 'SCALAR';
        return $actions;
    }

    return undef;
}

=item match2

This method tries to match a set of params in one or multiple sources.

If nothing matches undef will be returned

If there is a match hash will be returned with the following information

    {
        source_id => 'MATCH_SOURCE_ID'
        actions => [action0, action1],
        values => {
            type1 => value1,
            type2 => value2,
        },
    }

=cut

sub match2 {
    my $timer = pf::StatsD::Timer->new();
    my ($source_id, $params, $extra) = @_;
    my ($actions, @sources);
    $logger->debug( sub { "Match called with parameters ".join(", ", map { "$_ => $params->{$_}" } keys %$params) });

    # Calling 'match' with empty/invalid rule class. Using default
    if ( (!defined($params->{'rule_class'})) || (!exists($Rules::CLASSES{$params->{'rule_class'}})) ) {
        $params->{'rule_class'} = pf::Authentication::Rule->meta->get_attribute('class')->default;
        $logger->warn("Calling match with empty/invalid rule class. Defaulting to '" . $params->{'rule_class'} . "'");
    }

    #TODO: evaluate if we want to die or have another behavior
    my $context = $params->{'context'} // die "No authentication context provided";

    ($params->{'username'}, undef) = pf::config::util::strip_username_if_needed($params->{'username'}, $context);
    
    if (ref($source_id) eq 'ARRAY') {
        @sources = @{$source_id};
    } else {
        my $source = getAuthenticationSource($source_id);
        if (defined $source) {
            @sources = ($source);
        }
    }
    $logger->info("Using sources ".join(', ', (map {$_->id} @sources))." for matching");

    foreach my $source (@sources) {
        my $rule = $source->match($params, undef, $extra);
        next unless defined $rule;
        my %values;
        $actions = $rule->{actions};
        foreach my $action (@$actions) {
            my $value = $action->value;
            my $type  = $action->type;
            $value = $ACTION_VALUE_FILTERS{$type}->($value) if exists $ACTION_VALUE_FILTERS{$type};
            $type = $Actions::MAPPED_ACTIONS{$type} if exists $Actions::MAPPED_ACTIONS{$type};
            $values{$type} = $value;
        }

        return {
            source_id => $source->id,
            actions => $actions,
            values => \%values,
            rule_id => $rule->{id},
        };
    }

    return undef;
}

=item getAuthenticationClassByType

Get the authentication class by it's type

=cut

sub getAuthenticationClassByType {
    my ($type) = @_;
    $type = lc($type);
    if (!exists $TYPE_TO_SOURCE{$type}) {
        return undef;
    }
    return $TYPE_TO_SOURCE{$type}->meta->find_attribute_by_name('class')->default;
}

sub adminAuthentication {
  my ($user, $password) = @_;
  my $internal_sources = pf::authentication::getInternalAuthenticationSources();
  my ($stripped_username,$realm) = strip_username($user);
  $realm //= 'null';
  my $realm_source = pf::config::util::get_realm_authentication_source($stripped_username, $realm, $internal_sources);

  $realm_source = ref($realm_source) eq 'ARRAY' ? $realm_source : [$realm_source];

  foreach my $source (@{$realm_source}) {
    get_logger->info("Found a realm source ".$source->id." for user $stripped_username in realm $realm.");
    my ($result, $message, $source_id, $extra) = pf::authentication::authenticate( { 
            'username' => $user, 
            'password' => $password, 
            'rule_class' => $Rules::ADMIN,
            'context' => $pf::constants::realm::ADMIN_CONTEXT,
        }, $source);
    if ($result) {
        if ($result == $LOGIN_CHALLENGE ) {
          return $LOGIN_CHALLENGE;
        }

        $extra //= {};
        my $match = pf::authentication::match2([$source], { 
                username => $user,
                rule_class => $Rules::ADMIN, 
                context => $pf::constants::realm::ADMIN_CONTEXT,
            }, $extra);
        my $values = $match->{values};

        my $roles = $values->{$Actions::SET_ACCESS_LEVEL} // "NONE";
        $roles = [split /\s*,\s*/,$roles];

        my $tenant_id = $values->{$Actions::SET_TENANT_ID} // 0;

        return ((all{ $_ ne 'NONE'} @$roles), $roles, $tenant_id);
    }
  }
  return $LOGIN_FAILURE;
}

sub classForType {
    my ($type) = @_;
    if (!defined $type) {
        return undef;
    }

    $type = lc($type);
    if (exists $TYPE_TO_CLASS{$type}) {
        return $TYPE_TO_CLASS{$type}
    }

    return undef;
}

=back

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

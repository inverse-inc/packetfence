package pf::authentication;

=head1 NAME

pf::authentication

=head1 DESCRIPTION

=over

=cut

use strict;
use warnings;

use Log::Log4perl qw(get_logger);

use pf::constants;
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
use pfconfig::cached_array;
use pfconfig::cached_hash;

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
    my $display_username = (defined $username) ? $username : "(undefined)";

    $logger->debug(sub {"Authenticating '$display_username' from source(s) ".join(', ', map { $_->id } @sources) });

    foreach my $current_source (@sources) {
        my ($result, $message);
        $logger->trace("Trying to authenticate '$display_username' with source '".$current_source->id."'");
        eval {
            ($result, $message) = $current_source->authenticate($username, $password);
        };
        # First match wins!
        if ($result) {
            $logger->info("Authentication successful for $display_username in source ".$current_source->id." (".$current_source->type.")");
            return ($result, $message, $current_source->id);
        }
    }

    $logger->trace("Authentication failed for '$display_username' for all ".scalar(@sources)." sources");
    return ($FALSE, 'Wrong username or password.');
}

=item match

This method tries to match a set of params in one or multiple sources.

If action is undef, all actions will be returned.
If action is set, it will return the value of the action immediately.
If source_id_ref is defined then it will be set to the matching source_id

=cut

sub match {
    my ($source_id, $params, $action, $source_id_ref) = @_;
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
    if($source) {
        #Store the source id
        $$source_id_ref = $source->id if defined $source_id_ref && ref $source_id_ref eq 'SCALAR';

        if (defined $action ) {
            my $found_action = first { $_->type eq $action } @{$actions};
            if (defined $found_action) {
                $logger->debug("[".$source->id."] Returning '".$found_action->value."' for action $action for username ".$params->{'username'});
                return $found_action->value
            }
            $logger->debug("[".$source->id."] Params don't match rules for action $action for parameters ".join(", ", map { "$_ => $params->{$_}" } keys %$params));
            return;
        }

        if (defined $action) {
            $logger->debug("No source matches action $action");
        } elsif (defined $source) {
            $actions ||= [];
            $logger->debug("[".$source->id."] Returning actions ".join(', ', map { $_->type." = ".$_->value } @$actions ));
        }
    }

    return $actions;
}

=back

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

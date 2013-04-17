package pf::authentication;

=head1 NAME

pf::authentication

=head1 DESCRIPTION

=over

=cut

use strict;
use warnings;

use Log::Log4perl;

use pf::config;
use pf::config::cached;

use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::Authentication::Condition;
use pf::Authentication::Rule;
use pf::Authentication::Source;

use pf::Authentication::Source::ADSource;
use pf::Authentication::Source::EmailSource;
use pf::Authentication::Source::HtpasswdSource;
use pf::Authentication::Source::KerberosSource;
use pf::Authentication::Source::LDAPSource;
use pf::Authentication::Source::RADIUSSource;
use pf::Authentication::Source::SMSSource;
use pf::Authentication::Source::SQLSource;
use pf::Authentication::Source::FacebookSource;
use pf::Authentication::Source::GoogleSource;
use pf::Authentication::Source::GithubSource;
use List::Util qw(first);

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
            deleteAuthenticationSource
            writeAuthenticationConfigFile
       );
    @EXPORT_OK =
      qw(
            authenticate
            match
            username_from_email
       );

}

our %TYPE_TO_SOURCE = (
    'sql'      => pf::Authentication::Source::SQLSource->meta->name,
    'ad'       => pf::Authentication::Source::ADSource->meta->name,
    'htpasswd' => pf::Authentication::Source::HtpasswdSource->meta->name,
    'kerberos' => pf::Authentication::Source::KerberosSource->meta->name,
    'ldap'     => pf::Authentication::Source::LDAPSource->meta->name,
    'radius'   => pf::Authentication::Source::RADIUSSource->meta->name,
    'email'    => pf::Authentication::Source::EmailSource->meta->name,
    'sms'      => pf::Authentication::Source::SMSSource->meta->name,
    'facebook' => pf::Authentication::Source::FacebookSource->meta->name,
    'google'   => pf::Authentication::Source::GoogleSource->meta->name,
    'github'   => pf::Authentication::Source::GithubSource->meta->name
);

my %cfg; tie %cfg, 'pf::config::cached', ( -file => $authentication_config_file );
my $logger = Log::Log4perl->get_logger('pf::authentication');

readAuthenticationConfigFile();

=item availableAuthenticationSourceTypes

Return the list of source types, as defined in each of the class

=cut

sub availableAuthenticationSourceTypes {
    return [
            # internal sources
            pf::Authentication::Source::LDAPSource->meta->get_attribute('type')->default,
            pf::Authentication::Source::ADSource->meta->get_attribute('type')->default,
            #'SQL', -- don't offer sql for the moment
            pf::Authentication::Source::RADIUSSource->meta->get_attribute('type')->default,
            pf::Authentication::Source::KerberosSource->meta->get_attribute('type')->default,
            pf::Authentication::Source::HtpasswdSource->meta->get_attribute('type')->default,
            # external source
            pf::Authentication::Source::EmailSource->meta->get_attribute('type')->default,
            pf::Authentication::Source::SMSSource->meta->get_attribute('type')->default,
            pf::Authentication::Source::GoogleSource->meta->get_attribute('type')->default,
            pf::Authentication::Source::FacebookSource->meta->get_attribute('type')->default,
            pf::Authentication::Source::GithubSource->meta->get_attribute('type')->default,
           ];
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
    foreach my $source_id ( tied(%cfg)->Sections() ) {

        # We skip groups from our ini files
        if ($source_id =~ m/\s/) {
          next;
        }

        # Keep aside the source type
        my $type = tied(%cfg)->val($source_id, "type");
        delete $cfg{$source_id}{type};

        # Instantiate the source object
        my $current_source = newAuthenticationSource($type, $source_id, $cfg{$source_id});

        # Parse rules
        foreach my $rule_id ( tied(%cfg)->GroupMembers($source_id) ) {

            my ($id) = $rule_id =~ m/$source_id rule (\w+)/;
            my $current_rule = pf::Authentication::Rule->new({match => $Rules::ANY, id => $id});

            foreach my $parameter ( tied(%cfg)->Parameters($rule_id) ) {
                if ($parameter =~ m/condition(\d+)/) {
                    #print "Condition $1: " . tied(%cfg)->val($rule, $parameter) . "\n";
                    my ($attribute, $operator, $value) = split(',', tied(%cfg)->val($rule_id, $parameter), 3);

                    $current_rule->add_condition( pf::Authentication::Condition->new({attribute => $attribute,
                                                                                      operator => $operator,
                                                                                      value => $value}) );
                } elsif ($parameter =~ m/action(\d+)/) {
                    #print "Action: $1" . tied(%cfg)->val($rule_id, $parameter) . "\n";
                    my ($type, $value) = split('=', tied(%cfg)->val($rule_id, $parameter), 2);

                    if (defined $value) {
                        $current_rule->add_action( pf::Authentication::Action->new({type => $type,
                                                                                    value => $value}) );
                    } else {
                        $current_rule->add_action( pf::Authentication::Action->new({type => $type}) );
                    }

                } elsif ($parameter =~ m/match/) {
                    $current_rule->{'match'} = tied(%cfg)->val($rule_id, $parameter);
                } elsif ($parameter =~ m/description/) {
                    $current_rule->{'description'} = tied(%cfg)->val($rule_id, $parameter);
                }
            }

            $current_source->add_rule($current_rule);
        }

        push(@authentication_sources, $current_source);
    }
}

=item writeAuthenticationConfigFile

Write the configuration file to disk

=cut

sub writeAuthenticationConfigFile {
    my %ini;
    tie %ini, 'pf::config::cached', ( -file => $authentication_config_file);

    # Remove deleted sections
    my %new_sources = map { $_ => 1 } @authentication_sources;
    my @sources = tied(%ini)->Sections;
    foreach my $id (@sources) {
        unless ($new_sources{$id}) {
            tied(%ini)->DeleteSection($id);
        }
    }

    # Update existing sections and create new ones
    foreach my $source ( @authentication_sources ) {
        $logger->debug("Writing source " . $source->id . " (" . ref($source)->meta->name . ")");
        $ini{$source->{id}} = {};
        $ini{$source->{id}}{description} = $source->{'description'};

        for my $attr ( $source->meta->get_all_attributes ) {
            $attr = $attr->name;
            # Don't write static attributes (see pfappserver::Model::Authentication::Source::update)
            next if (grep { $_ eq $attr } qw[id rules unique class]);
            next unless ($source->{$attr});
            my $value = $source->{$attr};
            if (ref($value)) {
                $value = join(',', @$value);
            }
            $ini{$source->{id}}{$attr} = $value;
        }

        # We flush rules, including conditions and actions.
        foreach my $rule ( @{$source->{'rules'}} ) {
            my $rule_id = $source->{'id'} . " rule " . $rule->{'id'};

            # Since 'description' is defined in the parent section, set the paramater through the object
            # for proper initialization
            tied(%ini)->newval($rule_id, 'description', $rule->{'description'});
            $ini{$rule_id}{match} = $rule->{'match'};

            my $index = 0;
            foreach my $action ( @{$rule->{'actions'}} ) {
                my $action_id = 'action' . $index;
                if (defined $action->{'value'}) {
                    $ini{$rule_id}{$action_id} = $action->{'type'} . '=' . $action->{'value'};
                } else {
                    $ini{$rule_id}{$action_id} = $action->{'type'};
                }
                $index++;
            }

            $index = 0;
            foreach my $condition ( @{$rule->{'conditions'}} ) {
                my $condition_id = 'condition' . $index;
                $ini{$rule_id}{$condition_id} = $condition->{'attribute'} . ',' . $condition->{'operator'} . ',' . $condition->{'value'};
                $index++;
            }
        }
    }

    tied(%ini)->RewriteConfig();
}

=item getAuthenticationSource

Returns an instance of pf::Authentication::Source::* for the given id

=cut

sub getAuthenticationSource {
    my $id = shift;

    my $result;
    if ($id) {
        $result = first {$_->{id} eq $id} @authentication_sources;
    } else {
        $result = \@authentication_sources;
    }

    return $result;
}

sub getAuthenticationSourceByType {
    my $type = shift;

    my $result;
    if ($type) {
        $result = first {$_->{type} eq $type} @authentication_sources;
    }

    return $result;
}

=item deleteAuthenticationSource

Delete an authentication source along its rules. Returns the number of source(s)
deleted.

=cut

sub deleteAuthenticationSource {
    my $id = shift;

    my $result = 0;
    for (my $i = 0; $i < scalar(@authentication_sources); $i++) {
        my $source = $authentication_sources[$i];
        if ($source->{id} eq $id) {
            splice(@authentication_sources, $i, 1);
            $result = 1;
            last;
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

=item username_from_email

=cut

sub username_from_email {

    my ($email) = @_;

    $logger->info("Looking up username for email: $email");

    foreach my $source ( @authentication_sources ) {

        my $classname = $source->meta->name;

        if ($classname eq 'pf::Authentication::Source::ADSource' ||
            $classname eq 'pf::Authentication::Source::LDAPSource') {

            my $username = $source->username_from_email($email);

            if (defined $username) {
                return $username;
            }
        }
    }

    return undef;
}



=item authenticate

=cut

sub authenticate {
    my ( $username, $password, $auth_module ) = @_;

    #print "Authenticating $username with $password\n";
    foreach my $current_source ( @authentication_sources ) {

        # We skip sources we aren't interested in
        #if ( defined $auth_module && !($auth_module eq $current_source->{'type'}) ) {
        #  next;
        #}

        my ($result, $message) = $current_source->authenticate($username, $password);

        # First match wins!
        if ($result) {
            return ($result, $message, $current_source->id);
        }
    }

    return ($FALSE, 'Invalid username/password for all authentication sources.');
}

=item match

This method tries to match a set of params in a specific source. If source_id is
undef, all sources will be tried. If action is undef, all actions will be returned.

If action is set, it'll return the value of the action immediately.

=cut

sub match {
    my ($source_id, $params, $action) = @_;
    my $actions;

    foreach my $current_source ( @authentication_sources ) {
        $logger->info("Matching in source ".ref($current_source));
        if (defined $source_id && $source_id eq $current_source->id) {
            $actions = $current_source->match($params);
            last;
        } elsif (!defined $source_id) {
            $actions = $current_source->match($params);

            # First match in a source wins, and we stop looping
            if (defined $actions) {
                last;
            }
        }
    }

    if (defined $action && defined $actions) {
        foreach my $current_action ( @{$actions} ) {
            if ($current_action->type eq $action) {
                return $current_action->value;
            }
        }
        return undef;
    }

    return $actions;
}

sub matchByType {
    my ($type, $params, $action) = @_;

    my $actions;
    my $source = getAuthenticationSourceByType($type);
    if ($source) {
        $actions = $source->match($params);
    }

    if (defined $action && defined $actions) {
        foreach my $current_action ( @{$actions} ) {
            if ($current_action->type eq $action) {
                return $current_action->value;
            }
        }
        return undef;
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

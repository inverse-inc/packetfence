package pf::authentication;

=head1 NAME

pf::authentication

=head1 DESCRIPTION

=cut

use Config::IniFiles;
use Data::Dumper;
use strict;
use warnings;
use Log::Log4perl;

use pf::config qw($TRUE $FALSE $conf_dir);

use pf::Authentication::Action;
use pf::Authentication::Condition;
use pf::Authentication::Rule;
use pf::Authentication::Source;

use pf::Authentication::Source::ADSource;
use pf::Authentication::Source::HTTPPasswordSource;
use pf::Authentication::Source::KerberosSource;
use pf::Authentication::Source::LDAPSource;
use pf::Authentication::Source::RADIUSSource;
use pf::Authentication::Source::SQLSource;

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
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT = qw(
		  @authentication_sources
                  availableAuthenticationSourceTypes
                  newAuthenticationSource
                  getAuthenticationSource
                  deleteAuthenticationSource
                  writeAuthenticationConfigFile
		  authenticate
		  match
	       );
}

my %cfg; tie %cfg, 'Config::IniFiles', ( -file => "$conf_dir/authentication.conf" );
my $logger = Log::Log4perl->get_logger('pf::authentication');

readAuthenticationConfigFile();

=head2 availableAuthenticationSourceTypes

Return the list of source types, as defined in each of the class

=cut

sub availableAuthenticationSourceTypes {
    return [
            'LDAP',
            'AD',
            #'SQL', -- don't offer sql for the moment
            'RADIUS',
            'Kerberos',
            'Htpasswd'
           ];
}

=head2 newAuthenticationSource

Returns an instance of pf::Authentication::Source::* for the given type

=cut

sub newAuthenticationSource {
    my ($type, $source_id, $attrs) = @_;
    my $source;
    {
        # Microsoft Active Directory sources
        lc($type) eq 'ad' && do {
            $source = pf::Authentication::Source::ADSource->new(
                {
                 id => $source_id,
                 description => $attrs->{description},
                 host => $attrs->{host},
                 port => $attrs->{port},
                 basedn => $attrs->{basedn},
                 binddn => $attrs->{binddn},
                 password => $attrs->{password},
                 encryption => $attrs->{encryption},
                 scope => $attrs->{scope},
                 usernameattribute => $attrs->{usernameattribute}
                });
        };

        # Apache password style sources
        lc($type) eq 'htpasswd' && do {
            $source = pf::Authentication::Source::HTTPPasswordSource->new(
                {
                 id => $source_id,
                 description => $attrs->{description},
                 path => $attrs->{path}
                });
        };

        # Kerberos sources
        lc($type) eq 'kerberos' && do {
            $source = pf::Authentication::Source::KerberosSource->new(
                {
                 id => $source_id,
                 description => $attrs->{description},
                 host => $attrs->{host},
                 realm => $attrs->{realm}
                });
        };

        # LDAP sources
        lc($type) eq 'ldap' && do {
            $source = pf::Authentication::Source::LDAPSource->new(
                {
                 id => $source_id,
                 description => $attrs->{description},
                 host => $attrs->{host},
                 port => $attrs->{port},
                 basedn => $attrs->{basedn},
                 binddn => $attrs->{binddn},
                 password => $attrs->{password},
                 encryption => $attrs->{encryption},
                 scope => $attrs->{scope},
                 usernameattribute => $attrs->{usernameattribute}
                });
        };

        # RADIUS sources
        lc($type) eq 'radius' && do {
            $source = pf::Authentication::Source::RADIUSSource->new(
                {
                 id => $source_id,
                 description => $attrs->{description},
                 host => $attrs->{host},
                 port => $attrs->{port},
                 secret => $attrs->{secret}
                });
        };

        # SQL sources
        lc($type) eq 'sql' && do {
            $source = pf::Authentication::Source::SQLSource->new(
                {
                 id => $source_id,
                 description => $attrs->{description}
                });
        };
    }

    return $source;
}

=head2 readAuthenticationConfigFile

Populate @authentication_sources with object representations of the configuration file

=cut

sub readAuthenticationConfigFile {
    foreach my $source_id ( tied(%cfg)->Sections() ) {

        # We skip groups from our ini files
        if ($source_id =~ m/\s/) {
          next;
        }

        my $type = tied(%cfg)->val($source_id, "type");
        my $current_source = newAuthenticationSource($type, $source_id, $cfg{$source_id});

        # Parse rules
        foreach my $rule_id ( tied(%cfg)->GroupMembers($source_id) ) {

            my ($id) = $rule_id =~ m/$source_id rule (\w+)/;
            my $current_rule = pf::Authentication::Rule->new({match => pf::Authentication::Rule->ANY, id => $id});

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

=head2 writeAuthenticationConfigFile

Write the configuration file to disk

=cut

sub writeAuthenticationConfigFile {
    my %ini;
    tie %ini, 'Config::IniFiles', ( -file => "$conf_dir/authentication.conf" );

    print "Writing configuration...\n";

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
        print "Source " . $source->id . " (" . ref($source)->meta->name . ")\n";
        $ini{$source->{id}} = {};
        $ini{$source->{id}}{description} = $source->{'description'};

        my $classname = $source->meta->name;

        if ($classname eq 'pf::Authentication::Source::ADSource' ||
            $classname eq 'pf::Authentication::Source::LDAPSource') {
            if ($classname eq 'pf::Authentication::Source::LDAPSource') {
                $ini{$source->{id}}{type} = 'ldap';
            } else {
                $ini{$source->{id}}{type} = 'ad';
            }
            $ini{$source->{id}}{host} = $source->{'host'};
            $ini{$source->{id}}{port} = $source->{'port'};
            $ini{$source->{id}}{binddn} = $source->{'binddn'};
            $ini{$source->{id}}{basedn} = $source->{'basedn'};
            $ini{$source->{id}}{password} = $source->{'password'};
            $ini{$source->{id}}{encryption} = $source->{'encryption'};
            $ini{$source->{id}}{scope} = $source->{'scope'};
            $ini{$source->{id}}{usernameattribute} = $source->{'usernameattribute'};
        } elsif ($classname eq 'pf::Authentication::Source::HTTPPasswordSource') {
            $ini{$source->{id}}{type} = 'htpasswd';
            $ini{$source->{id}}{path} = $source->{'path'};
        } elsif ($classname eq 'pf::Authentication::Source::KerberosSource') {
            $ini{$source->{id}}{type} = 'kerberos';
            $ini{$source->{id}}{realm} = $source->{'realm'};
            $ini{$source->{id}}{host} = $source->{'host'};
        } elsif ($classname eq 'pf::Authentication::Source::RADIUSSource') {
            $ini{$source->{id}}{type} = 'radius';
            $ini{$source->{id}}{host} = $source->{'host'};
            $ini{$source->{id}}{port} = $source->{'port'};
            $ini{$source->{id}}{secret} = $source->{'secret'};
        } elsif ($classname eq 'pf::Authentication::Source::SQLSource') {
            $ini{$source->{id}}{type} = 'sql';
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

    tied(%ini)->WriteConfig( "$conf_dir/authentication.conf" );
}

=head2

Returns an instance of pf::Authentication::Source::* for the given id

=cut

sub getAuthenticationSource {
    my $id = shift;

    my $result;
    if ($id) {
        foreach my $source (@authentication_sources) {
            if ($source->{id} eq $id) {
                $result = $source;
            }
        }
    } else {
        $result = \@authentication_sources;
    }

    return $result;
}

=head2 deleteAuthenticationSource

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
# 	#print "Found user in $current_source->{'id'}\n";
# 	return $current_source;
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



=head2 authenticate

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
            return ($result, $message);
        }
    }
  
    return ($FALSE, 'Invalid username/password for all authentication sources.');
}

=head2 match

=cut

sub match {
    my $params = shift;

    foreach my $current_source ( @authentication_sources ) {
        $current_source->match($params);
    }
}

=back

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

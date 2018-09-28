package pf::Authentication::Source::LDAPSource;

=head1 NAME

pf::Authentication::Source::LDAPSource

=head1 DESCRIPTION

=cut

use pf::log;
use pf::constants qw($TRUE $FALSE);
use pf::constants::authentication::messages;
use pf::Authentication::constants qw($DEFAULT_LDAP_READ_TIMEOUT $DEFAULT_LDAP_WRITE_TIMEOUT $DEFAULT_LDAP_CONNECTION_TIMEOUT);
use pf::Authentication::Condition;
use pf::CHI;
use pf::util;
use Readonly;

use pf::LDAP;
use List::Util;
use Net::LDAP::Util qw(escape_filter_value);
use pf::config qw(%Config);
use List::MoreUtils qw(uniq any);
use pf::StatsD::Timer;
use pf::util::statsd qw(called);

use Moose;
extends 'pf::Authentication::Source';
with qw(pf::Authentication::InternalRole);

# available encryption
use constant {
    NONE => "none",
    SSL => "ssl",
    TLS => "starttls",
};

Readonly our %ATTRIBUTES_MAP => (
  'firstname'   => "givenName",
  'lastname'    => "sn",
  'address'     => "physicalDeliveryOfficeName",
  'telephone'   => "telephoneNumber",
  'email'       => "mailLocalAddress|mailAlternateAddress|mail",
  'work_phone'  => "homePhone",
  'cell_phone'  => "mobile",
  'company'     => "company",
  'title'       => "title",
);

has '+type' => (default => 'LDAP');
has 'host' => (isa => 'Maybe[Str]', is => 'rw', default => '');
has 'port' => (isa => 'Maybe[Int]', is => 'rw', default => 389);
has 'connection_timeout' => ( isa => 'Num', is => 'rw', default => $DEFAULT_LDAP_CONNECTION_TIMEOUT );
has 'write_timeout' => (isa => 'Num', is => 'rw', default => $DEFAULT_LDAP_WRITE_TIMEOUT);
has 'read_timeout' => (isa => 'Num', is => 'rw', default => $DEFAULT_LDAP_READ_TIMEOUT);
has 'basedn' => (isa => 'Str', is => 'rw', required => 1);
has 'binddn' => (isa => 'Maybe[Str]', is => 'rw');
has 'password' => (isa => 'Maybe[Str]', is => 'rw');
has 'encryption' => (isa => 'Str', is => 'rw', required => 1);
has 'scope' => (isa => 'Str', is => 'rw', required => 1);
has 'usernameattribute' => (isa => 'Str', is => 'rw', required => 1);
has 'searchattributes' => (isa => 'ArrayRef[Str]', is => 'rw', required => 0);
has '_cached_connection' => (is => 'rw');
has 'cache_match' => ( isa => 'Bool', is => 'rw', default => 0 );
has 'email_attribute' => (isa => 'Maybe[Str]', is => 'rw', default => 'mail');
has 'monitor' => ( isa => 'Bool', is => 'rw', default => 1 );
has 'shuffle' => ( isa => 'Bool', is => 'rw', default => 0 );

our $logger = get_logger();

=head1 METHODS

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Login' }


=head2 available_attributes

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my @ldap_attributes = $self->ldap_attributes;

  # We check if our username attribute is present, if not we add it.
  my $usernameattribute = $self->{'usernameattribute'};
  if ( length ($usernameattribute) && !grep {$_->{value} eq $usernameattribute } @ldap_attributes ) {
    push (@ldap_attributes, { value => $usernameattribute, type => $Conditions::LDAP_ATTRIBUTE });
  }

  return [@$super_attributes, sort { $a->{value} cmp $b->{value} } @ldap_attributes];
}

=head2 ldap_attributes

get the ldap attributes

=cut

sub ldap_attributes {
    my ($self) = @_;
    return map { { value => $_, type => $Conditions::LDAP_ATTRIBUTE } } @{$Config{advanced}->{ldap_attributes}};
}

=head2 authenticate

=cut

sub authenticate {
  my ( $self, $username, $password ) = @_;
  my $timer_stat_prefix = called() . "." .  $self->{'id'};
  my $timer = pf::StatsD::Timer->new({'stat' => "${timer_stat_prefix}", level => 6});
  my $before; # will hold time before StatsD calls

  my ($connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();

  if (!defined($connection)) {
    return ($FALSE, $COMMUNICATION_ERROR_MSG);
  }

  my $filter = $self->_makefilter($username);

  my $result = do {
    my $timer = pf::StatsD::Timer->new({'stat' => "${timer_stat_prefix}.search", level => 7});
    $connection->search(
      base => $self->{'basedn'},
      filter => $filter,
      scope => $self->{'scope'},
      attrs => ['dn']
    );
  };

  if ($result->is_error) {
    $logger->error("[$self->{'id'}] Unable to execute search $filter from $self->{'basedn'} on $LDAPServer:$LDAPServerPort");
    $pf::StatsD::statsd->increment(called() . "." . $self->{'id'} .".error.count" );
    return ($FALSE, $COMMUNICATION_ERROR_MSG);
  }

  if ($result->count == 0) {
    $logger->warn("[$self->{'id'}] No entries found (". $result->count .") with filter $filter from $self->{'basedn'} on $LDAPServer:$LDAPServerPort");
    $pf::StatsD::statsd->increment(called() . "." . $self->{'id'} . ".failure.count" );
    return ($FALSE, $AUTH_FAIL_MSG);
  } elsif ($result->count > 1) {
    $logger->warn("[$self->{'id'}] Unexpected number of entries found (" . $result->count .") with filter $filter from $self->{'basedn'} on $LDAPServer:$LDAPServerPort for source $self->{'id'}");
    $pf::StatsD::statsd->increment(called() . "." . $self->{'id'} . ".failure.count" );
    return ($FALSE, $AUTH_FAIL_MSG);
  }

  my $user = $result->entry(0);

  $result = do {
    my $timer = pf::StatsD::Timer->new({'stat' => "${timer_stat_prefix}.bind", level => 7});
    $connection->bind($user->dn, password => $password)
  };

  if ($result->is_error) {
    $logger->warn("[$self->{'id'}] User " . $user->dn . " cannot bind from $self->{'basedn'} on $LDAPServer:$LDAPServerPort");
    $pf::StatsD::statsd->increment(called() . "." . $self->{'id'} . ".failure.count" );
    return ($FALSE, $AUTH_FAIL_MSG);
  }

  $logger->info("[$self->{'id'}] Authentication successful for $username");
  return ($TRUE, $AUTH_SUCCESS_MSG);
}


=head2 _connect

Try every server in @LDAPSERVER in turn.
Returns the connection object and a valid LDAP server and port or undef
if all connections fail

=cut

sub _connect {
  my $self = shift;
  my $timer_stat_prefix = called() . "." .  $self->{'id'};
  my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}", level => 7});
  my $connection;
  my $logger = Log::Log4perl::get_logger(__PACKAGE__);
  my ($LDAPServer, $LDAPServerPort);
  my @LDAPServers = split(/\s*,\s*/, $self->{'host'});
  if ($self->shuffle) {
      @LDAPServers = List::Util::shuffle @LDAPServers;
  }
  my @credentials;
  if ($self->{'binddn'} && $self->{'password'}) {
    @credentials = ($self->{'binddn'}, password => $self->{'password'})
  }

  TRYSERVER:
  foreach my $s (@LDAPServers) {
    $LDAPServer = $s;
    $LDAPServerPort = undef;
    # check to see if the hostname includes a port (e.g. server:port)
    if ($LDAPServer =~ /:/) {
        $LDAPServerPort = (split(/:/, $LDAPServer))[-1];
    }
    $LDAPServerPort //=  $self->{'port'} ;
    $connection = pf::LDAP->new(
        $LDAPServer,
        port       => $LDAPServerPort,
        timeout    => $self->{'connection_timeout'},
        write_timeout  => $self->{'write_timeout'},
        read_timeout  => $self->{'read_timeout'},
        encryption => $self->{encryption},
        credentials => \@credentials,
    );

    if (! defined($connection)) {
      $logger->warn("[$self->{'id'}] Unable to connect to $LDAPServer");
      next TRYSERVER;
    }


    $logger->debug("[$self->{'id'}] Using LDAP connection to $LDAPServer");
    return ( $connection, $LDAPServer, $LDAPServerPort );
  }
  # if the connection is still undefined after trying every server, we fail and return undef.
  if (! defined($connection)) {
    $logger->error("[$self->{'id'}] Unable to connect to any LDAP server");
    $pf::StatsD::statsd->increment("${timer_stat_prefix}.error.count" );
  }
  return (undef, $LDAPServer, $LDAPServerPort);
}


=head2 cache

    get the cache object

=cut

sub cache {
    return pf::CHI->new( namespace => 'ldap_auth');
}

=head2 match_rule

match_rule

=cut

sub match_rule {
    my ($self, $rule, $params, $extra) = @_;
    if ($self->is_rule_cacheable($rule)) {
        return $self->cache->compute_with_undef($self->rule_cache_key($rule, $params, $extra), sub {
            $pf::StatsD::statsd->increment("pf::Authentication::Source::LDAPSource::match_rule.$self->{id}.cache_miss.count" );
            return $self->SUPER::match_rule($rule, $params, $extra);
        });
    }
    return $self->SUPER::match_rule($rule, $params, $extra);
}

our %NON_CACHEABLE_OPS = (
   $Conditions::IS_BEFORE => 1, 
   $Conditions::IS_AFTER => 1, 
   $Conditions::IN_TIME_PERIOD => 1, 
);


=head2 is_rule_cacheable

is_rule_cacheable

=cut

sub is_rule_cacheable {
    my ($self, $rule) = @_;
    if (!defined ($rule) || !$self->cache_match) {
        return $FALSE;
    }
    return (any { exists $NON_CACHEABLE_OPS{$_->{operator} // ''}  } @{$rule->{'conditions'} // []}) ? $FALSE : $TRUE;
}


=head2 rule_cache_key

rule_cache_key

=cut

sub rule_cache_key {
    my ($self, $rule, $params, $extra) = @_;
    my %temp = %{$params // {}};
    delete @temp{qw(current_date current_time current_time_period radius_request)};
    return [$self->{id}, $rule->{id}, \%temp ];
}

=head2 match_in_subclass

match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    my $filter = $self->ldap_filter_for_conditions($own_conditions, $rule->match, $self->{'usernameattribute'}, $params);
    my $id = $self->id;
    if (! defined($filter)) {
        $logger->error("[$id] Missing parameters to construct LDAP filter");
        $pf::StatsD::statsd->increment(called() . "." . $id . ".error.count" );
        return undef;
    }
    my $rule_id = $rule->id;
    $logger->debug("[$id $rule_id] Searching for $filter, from $self->{'basedn'}, with scope $self->{'scope'}");
    return $self->_match_in_subclass($filter, $params, $rule, $own_conditions, $matching_conditions);
}

=head2 _match_in_subclass

C<$params> are the parameters gathered at authentication (username, SSID, connection type, etc).

C<$rule> is the rule instance that defines the conditions.

C<$own_conditions> are the conditions specific to an LDAP source.

Conditions that match are added to C<$matching_conditions>.

=cut

sub _match_in_subclass {
    my ($self, $filter, $params, $rule, $own_conditions, $matching_conditions) = @_;
    my $timer_stat_prefix = called() . "." .  $self->{'id'};
    my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}",  level => 6});

    my $cached_connection = $self->_cached_connection;
    unless ( $cached_connection ) {
        return undef;
    }
    my ( $connection, $LDAPServer, $LDAPServerPort ) = @$cached_connection;



    my @attributes = map { $_->{'attribute'} } @{$own_conditions};
    my $result = do {
        my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}.search",  level => 6});
        $connection->search(
          base => $self->{'basedn'},
          filter => $filter,
          scope => $self->{'scope'},
          attrs => \@attributes
        )
    };

    if ($result->is_error) {
        $logger->error("[$self->{'id'}] Unable to execute search $filter from $self->{'basedn'} on $LDAPServer:$LDAPServerPort, we skip the rule.");
        $pf::StatsD::statsd->increment(called() . "." . $self->{'id'} . ".error.count" );
        return undef;
    }

    $logger->debug("[$self->{'id'} $rule->{'id'}] Found ".$result->count." results");
    if ($result->count == 1) {
        my $entry = $result->pop_entry();
        my $dn = $entry->dn;
        my $entry_matches = 1;
        my ($condition, $attribute, $value);

        # Perform match on regexp conditions since they were not included in the LDAP filter
        foreach $condition (grep { $_->{'operator'} eq $Conditions::MATCHES } @{$own_conditions}) {
            $attribute = $condition->{'attribute'};
            $value = $condition->{'value'};
            my @attributes = $entry->get_value($attribute);
            if (scalar @attributes > 0 && grep /$value/i, @attributes) {
                $entry_matches = 1;
                $logger->debug("[$self->{'id'} $rule->{'id'}] Regexp $attribute =~ /$value/ matches ($dn)");
                last if ($rule->match eq $Rules::ANY)
            }
            else {
                $entry_matches = 0;
                if ($rule->match eq $Rules::ALL) {
                    last;
                }
            }
        }

        # Perform match on a static group condition since they require a second LDAP search
        foreach $condition (grep { $_->{'operator'} eq $Conditions::IS_MEMBER } @{$own_conditions}) {
            $value = escape_filter_value($condition->{'value'});
            $attribute = $entry->get_value($condition->{'attribute'}) // '';
            $attribute = escape_filter_value($attribute);
            # Search for any type of group definition:
            # - groupOfNames       => member (dn)
            # - groupOfUniqueNames => uniqueMember (dn)
            # - posixGroup         => memberUid (uid)
            my $dn_search = escape_filter_value($dn);
            $filter = "(|(member=${dn_search})(uniqueMember=${dn_search})(memberUid=${attribute}))";
            $logger->debug("[$self->{'id'} $rule->{'id'}] Searching is_member filter $filter");
            $result = $connection->search
              (
               base => $value,
               filter => $filter,
               scope => $self->{ 'scope'},
               attrs => ['dn']
              );
            if ($result->is_error || $result->count != 1) {
                $entry_matches = 0;
                if ( $result->is_error ) {
                    $pf::StatsD::statsd->increment(called() . "." . $self->{'id'} . ".error.count" );
                    $logger->error(
                        "[$self->{'id'}] Unable to execute search $filter from $value on $LDAPServer:$LDAPServerPort, we skip the condition ("
                        . $result->error . ").");
                }

                if ($rule->match eq $Rules::ALL) {
                    last;
                }
            }
            else {
                $entry_matches = 1;
                $logger->debug("[$self->{'id'} $rule->{'id'}] Group $value has member $attribute ($dn)");
                last if ($rule->match eq $Rules::ANY);
            }
        }

        if ($entry_matches) {
            # If we found a result, we push all conditions as matched ones.
            # That is normal, as we used them all to build our LDAP filter.
            $logger->trace("[$self->{'id'} $rule->{'id'}] Found a match ($dn)");
            push @{ $matching_conditions }, @{ $own_conditions };
            return $params->{'username'} || $params->{'email'};
        }
    }
    elsif($result->count > 1) {
        $logger->warn("[$self->{'id'} $rule->{'id'}] Found more than 1 match. Ignoring all of them. Make sure your filtering rules (on username and on email) can only return a single result");
    }
    else {
        $logger->debug("[$self->{'id'} $rule->{'id'}] No match found for this LDAP filter");
    }

    return undef;
}

=head2 test

Test if we can bind and search to the LDAP server

=cut

sub test {
  my ($self) = @_;

  # Connect
  my ( $connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();
  my $id = $self->{id};

  if (!defined($connection)) {
    my $binddn = $self->{'binddn'} // '';
    $logger->warn("[$id] Unable to connect to any LDAP server");
    return ($FALSE, "Can't connect to server or bind with '$binddn' on $LDAPServer:$LDAPServerPort");
  }
  my $base = $self->{basedn};
  # Search
  my $filter = "($self->{'usernameattribute'}=packetfence)";
  my $result = $connection->search(
    base => $base,
    filter => $filter,
    scope => $self->{'scope'},
    attrs => ['dn'],
    sizelimit => 1,
  );

  if ($result->is_error) {
      $logger->warn("[$id] Unable to execute search $filter from '$base' on $LDAPServer:$LDAPServerPort: " . ($result->error // '' ));
      return ($FALSE, 'Wrong base DN or username attribute');
  }

  return ($TRUE, 'LDAP connect, bind and search successful');
}

=head2 ldap_filter_for_conditions

This function is used to generate an LDAP filter based on conditions
from a rule.

In case of a catch all, there's no condition and we only check
for the usernameattribute - to match it in the source.

=cut

sub ldap_filter_for_conditions {
  my ($self, $conditions, $match, $usernameattribute, $params) = @_;
  my $timer_stat_prefix = called() . "." .  $self->{'id'};
  my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}",  level => 7});

  my (@ldap_conditions, $expression);

  if ($params->{'username'}) {
      $expression = '(' . $usernameattribute . '=' . $params->{'username'} . ')';
  } elsif ($params->{'email'}) {
      $expression = '(|(' . $self->{'email_attribute'} . '=' . $params->{'email'} . ')(proxyAddresses=smtp:' . $params->{'email'} . ')(mailLocalAddress=' . $params->{'email'} . ')(mailAlternateAddress=' . $params->{'email'} . '))';
  }

  if ($expression) {
      my $logical_op = ($match eq $Rules::ANY) ? '|' :   '&';
      foreach my $condition (@{$conditions}) {
          my $str;
          my $operator = $condition->{'operator'};
          my $value = escape_filter_value($condition->{'value'});
          my $attribute = $condition->{'attribute'};

          if ($operator eq $Conditions::EQUALS) {
              $str = "${attribute}=${value}";
          } elsif ($operator eq $Conditions::NOT_EQUALS) {
              $str = "!(${attribute}=${value})";
          } elsif ($operator eq $Conditions::CONTAINS) {
              $str = "${attribute}=*${value}*";
          } elsif ($operator eq $Conditions::STARTS) {
              $str = "${attribute}=${value}*";
          } elsif ($operator eq $Conditions::ENDS) {
              $str = "${attribute}=*${value}";
          }

          if ($str) {
              push(@ldap_conditions, $str);
          }
      }
      if (@ldap_conditions) {
          my $subexpressions = join('', map { "($_)" } @ldap_conditions);
          if (@ldap_conditions > 1) {
              $subexpressions = "(${logical_op}${subexpressions})";
          }
          $expression = "(&${expression}${subexpressions})";
      }
  }

  return $expression;
}

=head2 search based on a attribute

=cut

sub search_attributes_in_subclass {
    my ($self, $username) = @_;
    my $timer_stat_prefix = called() . "." .  $self->{'id'};
    my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}",  level => 6});
    my ($connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();
    if (!defined($connection)) {
      return ($FALSE, $COMMUNICATION_ERROR_MSG);
    }

    my $searchresult = $connection->search(
                  base => $self->{'basedn'},
                  filter => "($self->{'usernameattribute'}=$username)"
    );
    if ($searchresult->is_error()) {
      $logger->error("Unable to locate user '$username'");
      return ($FALSE, $COMMUNICATION_ERROR_MSG);
    }
    if ($searchresult->count == 0) {
      $logger->error("Unable to locate user '$username'");
      return ($FALSE, $COMMUNICATION_ERROR_MSG);
    }
    my $entry = $searchresult->entry();

    $logger->info("User: '$username' found in the directory");

    my $info = {};
    foreach my $attrs (keys %ATTRIBUTES_MAP){
        foreach my $attr (split('\|',$ATTRIBUTES_MAP{$attrs})) {
            if(defined($entry->get_value($attr))){
                $info->{$attrs} = $entry->get_value($attr);
            }
        }
    }
    return $info;
}

=head2 postMatchProcessing

Tear down any resources created in preMatchProcessing

=cut

sub postMatchProcessing {
    my ($self) = @_;
    my $cached_connection = $self->_cached_connection;
    if($cached_connection) {
        my ( $connection, $LDAPServer, $LDAPServerPort ) = @$cached_connection;
        $self->_cached_connection(undef);
    }
}

=head2 preMatchProcessing

Setup any resouces need for matching

=cut

sub preMatchProcessing {
    my ($self) = @_;
    my ( $connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();
    if (! defined($connection)) {
        return undef;
    }

    $self->_cached_connection([$connection, $LDAPServer, $LDAPServerPort]);
}

=head2 _makefilter

Create the filter to search for the dn

=cut

sub _makefilter {
  my ($self,$username) = @_;
  my $search = join ("", map { "($_=$username)" } @{$self->{'searchattributes'}});
  return "(|$search)";
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

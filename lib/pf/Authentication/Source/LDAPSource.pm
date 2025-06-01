package pf::Authentication::Source::LDAPSource;

=head1 NAME

pf::Authentication::Source::LDAPSource

=head1 DESCRIPTION

=cut

use pf::log;
use pf::constants qw($TRUE $FALSE);
use pf::constants::authentication::messages;
use pf::Authentication::constants qw($DEFAULT_LDAP_READ_TIMEOUT $DEFAULT_LDAP_WRITE_TIMEOUT $DEFAULT_LDAP_CONNECTION_TIMEOUT $DEFAULT_LDAP_DEAD_DURATION);
use pf::Authentication::Condition;
use pf::CHI;
use pf::util;
use Readonly;

use pf::LDAP;
use List::Util;
use Net::LDAP::Util qw(escape_filter_value);
use pf::config qw(%Config);
use List::MoreUtils qw(uniq any firstval none);
use pf::StatsD::Timer;
use pf::util::statsd qw(called);

use Moose;
use pf::Moose::Types;
extends 'pf::Authentication::Source';
with qw(pf::Authentication::InternalRole);

# available encryption
use constant {
    NONE => "none",
    SSL => "ssl",
    TLS => "starttls",
};

our %sslargs_mapping = (
    verify      => 'verify',
    client_cert_file => 'clientcert',
    client_key_file  => 'clientkey',
    ca_file     => 'cafile',
);

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
has 'host' => (isa => 'ArrayOfStr', is => 'rw', default => sub { [] }, coerce => 1);
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
has 'append_to_searchattributes' => (isa => 'Maybe[Str]', is => 'rw', required => 0);
has '_cached_connection' => (is => 'rw');
has 'cache_match' => ( isa => 'Bool', is => 'rw', default => '0' );
has 'email_attribute' => (isa => 'Maybe[Str]', is => 'rw', default => 'mail');
has 'monitor' => ( isa => 'Bool', is => 'rw', default => '1' );
has 'shuffle' => ( isa => 'Bool', is => 'rw', default => '0' );
has 'dead_duration' => ( isa => 'Num', is => 'rw', default => $DEFAULT_LDAP_DEAD_DURATION);
has 'client_cert_file' => ( isa => 'Maybe[Str]', is => 'rw', default => "");
has 'client_key_file' => ( isa => 'Maybe[Str]', is => 'rw', default => "");
has 'ca_file' => (isa => 'Maybe[Str]', is => 'rw', default => '');
has 'verify' => ( isa => 'Str', is => 'rw', default => 'none');
has 'use_connector' => (isa => 'Bool', is => 'rw', default => 1);
has '_ldap_attributes' => ( isa => 'ArrayRef', is => 'rw', default => sub { [] });

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
    push(@$super_attributes, @ldap_attributes);
    my %seen;
    @$super_attributes = grep { ! $seen{$_->{value}}++ } @$super_attributes;

    return [{ value => $Conditions::LDAP_FILTER, type => $Conditions::LDAP_FILTER  }, sort { lc($a->{value}) cmp lc($b->{value}) } @$super_attributes]
}

=head2 ldap_attributes

get the ldap attributes

=cut

sub ldap_attributes {
    my ($self) = @_;
    my @ldap_attributes = (
        (map { { value => $_, type => $Conditions::LDAP_ATTRIBUTE } } @{$Config{advanced}->{ldap_attributes}}),
        @{$self->_ldap_attributes},
    );

    my %seen;
    return grep { !$seen{$_->{value}}++ } @ldap_attributes;
}

=head2 common_attributes

Add the radius attributes to the common attributes

=cut

sub common_attributes {
    my $self = shift;
    my $super_common_attributes = $self->SUPER::common_attributes;
    my @radius_attributes = map { {value => "radius_request.".$_, type => $Conditions::SUBSTRING}} qw(
        TLS-Client-Cert-Serial
        TLS-Client-Cert-Expiration
        TLS-Client-Cert-Issuer
        TLS-Client-Cert-Subject
        TLS-Client-Cert-Common-Name
        TLS-Client-Cert-Filename
        TLS-Client-Cert-Subject-Alt-Name-Email
        TLS-Client-Cert-X509v3-Extended-Key-Usage
        TLS-Cert-Serial
        TLS-Cert-Expiration
        TLS-Cert-Issuer
        TLS-Cert-Subject
        TLS-Cert-Common-Name
        TLS-Client-Cert-Subject-Alt-Name-Dns
    );

    push(@radius_attributes, map { {value => "radius_request.".$_, type => $Conditions::SUBSTRING}} @{$Config{radius_configuration}->{radius_attributes}});
    push(@$super_common_attributes, @radius_attributes);

    return $super_common_attributes;
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

  my $filter = $self->_makefilter(escape_filter_value($username));

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
    $logger->error("[$self->{'id'}] Unable to execute search $filter from $self->{'basedn'} on $LDAPServer:$LDAPServerPort :" . $result->error_desc());
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
    $logger->warn("[$self->{'id'}] User " . $user->dn . " cannot bind from $self->{'basedn'} on $LDAPServer:$LDAPServerPort: " . $result->error_desc());
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
  my $LDAPServer;
  # Lookup the server hostnames to IPs so they can be shuffled better and to improve the failure detection
  my @LDAPServers = map { valid_ip($_) ? $_ : @{resolve($_) // []} } @{$self->{'host'} // []};
  if ($self->shuffle) {
      @LDAPServers = List::Util::shuffle @LDAPServers;
  }

  my $LDAPServerPort =  $self->{'port'} ;
  my %LDAPArgs = $self->_LDAPArgs();
  my $try_connect = sub {
      my $honor_dead = shift;
      TRYSERVER:
      foreach my $s (@LDAPServers) {
        $LDAPServer = $s;
        $LDAPServerPort =  $self->{'port'} ;
        
        my $dead_cache_key = "SERVER_DEAD:".$self->{id}.":$LDAPServer";

        if($honor_dead && $self->cache->get($dead_cache_key)) {
          $logger->warn("[$self->{'id'}] $LDAPServer detected as dead, switching to next server");
          next TRYSERVER;
        }

        if($self->use_connector) {
            require pf::factory::connector;
            my $connector_conn = pf::factory::connector->for_ip($LDAPServer)->dynreverse("$LDAPServer:$LDAPServerPort");
            $connection = pf::LDAP->new(
                $connector_conn->{host},
                %LDAPArgs,
                port => $connector_conn->{port},
            );
        } 
        else {
            $connection = pf::LDAP->new(
                $LDAPServer,
                %LDAPArgs,
            );
        }


        if (! defined($connection)) {
          $logger->warn("[$self->{'id'}] Unable to connect to $LDAPServer");
          if($honor_dead && $self->dead_duration) {
              $self->cache->set($dead_cache_key, $TRUE, $self->dead_duration);
          }
          next TRYSERVER;
        }


        $logger->debug("[$self->{'id'}] Using LDAP connection to $LDAPServer");
        return ( $connection, $LDAPServer, $LDAPServerPort );
      }
      return ( undef, $LDAPServer, $LDAPServerPort );
  };

  ($connection, $LDAPServer, $LDAPServerPort) = $try_connect->($TRUE);

  if (! defined($connection)) {
    $logger->error("[$self->{'id'}] Unable to connect to any LDAP server, will try while ignoring the dead servers detection");
    $pf::StatsD::statsd->increment("${timer_stat_prefix}.error.count" );
  } else {
    return ($connection, $LDAPServer, $LDAPServerPort);
  }
  
  # If we're here then all servers were marked dead or failed to get a valid connection
  # We now try again without honoring the dead servers flags
  ($connection, $LDAPServer, $LDAPServerPort) = $try_connect->($FALSE);
  
  if (! defined($connection)) {
    $logger->error("[$self->{'id'}] Unable to connect to any LDAP server");
    $pf::StatsD::statsd->increment("${timer_stat_prefix}.error.count" );
    return (undef, $LDAPServer, $LDAPServerPort);
  } else {
    return ($connection, $LDAPServer, $LDAPServerPort);
  }
}

sub _LDAPArgs {
    my ($self) = @_;
    my @credentials;
    if ( $self->{'binddn'} && $self->{'password'} ) {
        @credentials = ( $self->{'binddn'}, password => $self->{'password'} );
    }
    my $encryption  = $self->{encryption};
    my %args = (
        credentials   => \@credentials,
        port          => $self->{'port'},
        timeout       => $self->{'connection_timeout'},
        write_timeout => $self->{'write_timeout'},
        read_timeout  => $self->{'read_timeout'},
        encryption    => $encryption,
    );

    if ($encryption eq SSL) {
        $self->addSSLArgs(\%args)
    } elsif ($encryption eq TLS) {
        my %start_tls_options;
        $self->addSSLArgs(\%start_tls_options);
        $args{start_tls_options} = \%start_tls_options;
    }

    return %args;
}

sub addSSLArgs {
    my ($self, $args) = @_;
    while (my ($k1, $k2) = each %sslargs_mapping) {
        next if !exists $self->{$k1};
        my $v = $self->{$k1};
        next if !$v;
        $args->{$k2} = $v;
    }
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
        my $results = $self->cache->compute_with_undef($self->rule_cache_key($rule, $params, $extra), sub {
            $pf::StatsD::statsd->increment("pf::Authentication::Source::LDAPSource::match_rule.$self->{id}.cache_miss.count" );
            return [$self->SUPER::match_rule($rule, $params, $extra)];
        });
        return @{$results // []};
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
    my %allowed_conditions = map { $_->{attribute} => 1 } @{$rule->{conditions} // []};
    my @key_values = (
        $self->{id},
        $rule->{id},
        $rule->{class},
        $rule->{cache_key},
        $params->{username} || $params->{email} || '',
        (
            map {
                my $v = $_->{value};
                ($v => $params->{$v})
            } grep { $_->{type} ne $Conditions::LDAP_ATTRIBUTE && exists $allowed_conditions{$_->{value}} } @{$self->common_attributes() // []}
        )
    );
    return \@key_values;
}

=head2 match_in_subclass

match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    my $basedn = $self->{'basedn'};
    my ($filter, $forcedbasedn) = $self->ldap_filter_for_conditions($own_conditions, $rule->match, $self->{'usernameattribute'}, $params);
    my $id = $self->id;
    if (! defined($filter)) {
        $logger->error("[$id] Missing parameters to construct LDAP filter");
        $pf::StatsD::statsd->increment(called() . "." . $id . ".error.count" );
        return (undef, undef);
    }
    if (defined($forcedbasedn) && $forcedbasedn ne '') {
        $basedn = $forcedbasedn;
    }
    my $rule_id = $rule->id;
    $logger->warn("[$id $rule_id] Searching for $filter, from $basedn, with scope $self->{'scope'}");
    return $self->_match_in_subclass($basedn, $filter, $params, $rule, $own_conditions, $matching_conditions);
}

=head2 _match_in_subclass

C<$params> are the parameters gathered at authentication (username, SSID, connection type, etc).

C<$rule> is the rule instance that defines the conditions.

C<$own_conditions> are the conditions specific to an LDAP source.

C<$basedn> is the basedn of the search

Conditions that match are added to C<$matching_conditions>.

=cut

sub _match_in_subclass {
    my ($self, $basedn, $filter, $params, $rule, $own_conditions, $matching_conditions) = @_;
    my $timer_stat_prefix = called() . "." .  $self->{'id'};
    my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}",  level => 6});

    my $cached_connection = $self->_cached_connection;
    unless ( $cached_connection ) {
        my ($connection, $LDAPServer, $LDAPServerPort) = $self->_connect();
        if (! defined($connection)) {
            return (undef, undef);
        }

        $cached_connection = [$connection, $LDAPServer, $LDAPServerPort];
        $self->_cached_connection($cached_connection);
    }
    my ( $connection, $LDAPServer, $LDAPServerPort ) = @$cached_connection;
    my @attributes = map { $_->{'attribute'} } @{$own_conditions};
    if (my $action = firstval { $_->type eq $Actions::SET_ROLE_FROM_SOURCE } @{$rule->{actions} // []}) {
        push @attributes, $action->value;
    }

    my $result = do {
        my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}.search",  level => 6});
        $connection->search(
          base => $basedn,
          filter => $filter,
          scope => $self->{'scope'},
          attrs => \@attributes
        )
    };

    if ($result->is_error) {
        $logger->error("[$self->{'id'}] Unable to execute search $filter from $basedn on $LDAPServer:$LDAPServerPort, we skip the rule.");
        $pf::StatsD::statsd->increment(called() . "." . $self->{'id'} . ".error.count" );
        return (undef, undef);
    }

    my $result_count = $result->count;
    $logger->debug("[$self->{'id'} $rule->{'id'}] Found $result_count results");
    if ($result_count == 1) {
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
            if ( (any {$_->type eq $Actions::SET_ROLE_ON_NOT_FOUND } @{$rule->{actions} // []}) && (none {$_->type eq $Actions::SET_ROLE } @{$rule->{actions} // []}) ) {
                $logger->trace("[$self->{'id'} $rule->{'id'}] match ($dn) but no set role action, continue");
            } else {
                push @{ $matching_conditions }, @{ $own_conditions };
                return ((($params->{'username'} || $params->{'email'}) ? $entry : undef), $Actions::SET_ROLE_ON_NOT_FOUND);
            }
        }
    }
    elsif($result_count > 1) {
        $logger->warn("[$self->{'id'} $rule->{'id'}] Found more than 1 match. Ignoring all of them. Make sure your filtering rules (on username and on email) can only return a single result");
    }
    else {
        $logger->debug("[$self->{'id'} $rule->{'id'}] No match found for this LDAP filter");
        if (any {$_->type eq $Actions::SET_ROLE_ON_NOT_FOUND } @{$rule->{actions} // []} ) {
            push @{ $matching_conditions }, @{ $own_conditions };
            return ($params->{'username'} || $params->{'email'}, $Actions::SET_ROLE);
        }
    }

    return (undef, undef);
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
  if (my $filter = firstval { $_->operator eq $Conditions::MATCH_FILTER } @{$conditions // []}) {
       return $self->update_template($filter->value, $params);
  }
  my $basedn;

  my (@ldap_conditions, $expression);

  if ($params->{'username'}) {
      $expression = $self->_makefilter($params->{'username'});
  } elsif ($params->{'email'}) {
      $expression = '(|(' . $self->{'email_attribute'} . '=' . $params->{'email'} . ')(proxyAddresses=smtp:' . $params->{'email'} . ')(mailLocalAddress=' . $params->{'email'} . ')(mailAlternateAddress=' . $params->{'email'} . '))';
  }

  if ($expression) {
      my $logical_op = ($match eq $Rules::ANY) ? '|' :   '&';
      foreach my $condition (@{$conditions}) {
          my $str;
          my $operator = $condition->{'operator'};
          my $attribute = $condition->{'attribute'};
          if ($attribute eq "basedn") {
              $basedn = $condition->{'value'};
              next;
          }

          my $value = escape_filter_value($condition->{'value'});
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

  return ($expression, $basedn);
}

sub replaceVar {
    my ($name, $params) = @_;
    return escape_filter_value(exists $params->{$name} ? $params->{$name} : '');
}

sub update_template {
    my ($self, $template, $params) = @_;
    $template =~ s/\$\{([a-zA-Z0-9]+([._-][a-zA-Z0-9]+)*)\}/replaceVar($1, $params)/ge;
    return $template;
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

=head2 _makefilter

Create the filter to search for the dn

=cut

sub _makefilter {
    my ($self,$username) = @_;
    my $append_search = defined($self->{'append_to_searchattributes'}) ? $self->{'append_to_searchattributes'} : '';
    if (@{$self->{'searchattributes'} // []}) {
        my $search = join ("", map { "($_=$username)" } uniq($self->{'usernameattribute'}, @{$self->{'searchattributes'}}));
        return "(&(|$search)".$append_search.")";
    } else {
        return '(' . "$self->{'usernameattribute'}=$username" . ')';
    }
}

sub lookupRole {
    my ($self, $rule, $role_info, $params, $extra, $entry, $attributes) = @_;
    if (ref($entry) eq '') {
        return undef;
    }
    foreach my $attr ( $entry->attributes ) {
        $$attributes->{"ldap_attribute"}->{$attr} = $entry->get_value( $attr, asref => 1) ;
    }
    if (ref($entry) && (my $action = firstval { $_->type eq $Actions::SET_ROLE_FROM_SOURCE } @{$rule->{actions} // []})) {
        return scalar $entry->get_value($action->value);
    }

    return undef;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

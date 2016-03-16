package pf::Authentication::Source::LDAPSource;

=head1 NAME

pf::Authentication::Source::LDAPSource

=head1 DESCRIPTION

=cut

use pf::log;
use pf::constants qw($TRUE $FALSE);
use pf::constants::authentication::messages;
use pf::Authentication::constants;
use pf::Authentication::Condition;
use pf::CHI;
use pf::util;
use Readonly;

use pf::LDAP;
use List::Util;
use Net::LDAP::Util qw(escape_filter_value);
use pf::config;
use List::MoreUtils qw(uniq);
use pf::StatsD::Timer;
use pf::util::statsd qw(called);
use List::Util qw(any all);
use List::MoreUtils qw(part);

use Moose;
extends 'pf::Authentication::Source';

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
has 'host' => (isa => 'Maybe[Str]', is => 'rw', default => '127.0.0.1');
has 'port' => (isa => 'Maybe[Int]', is => 'rw', default => 389);
has 'connection_timeout' => ( isa     => 'Int', is => 'rw', default => 5 );
has 'basedn' => (isa => 'Str', is => 'rw', required => 1);
has 'binddn' => (isa => 'Maybe[Str]', is => 'rw');
has 'password' => (isa => 'Maybe[Str]', is => 'rw');
has 'encryption' => (isa => 'Str', is => 'rw', required => 1);
has 'scope' => (isa => 'Str', is => 'rw', required => 1);
has 'usernameattribute' => (isa => 'Str', is => 'rw', required => 1);
has 'stripped_user_name' => (isa => 'Str', is => 'rw', default => 'yes');
has '_cached_connection' => (is => 'rw');
has 'cache_match' => ( isa => 'Bool', is => 'rw', default => 0 );
has 'email_attribute' => (isa => 'Maybe[Str]', is => 'rw', default => 'mail');

our $logger = get_logger();

=head1 METHODS

=head2 available_attributes

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my @attributes = @{$Config{advanced}->{ldap_attributes}};
  my @ldap_attributes = map { { value => $_, type => $Conditions::LDAP_ATTRIBUTE } } @attributes;

  # We check if our username attribute is present, if not we add it.
  if (not grep {$_->{value} eq $self->{'usernameattribute'} } @ldap_attributes ) {
    push (@ldap_attributes, { value => $self->{'usernameattribute'}, type => $Conditions::LDAP_ATTRIBUTE });
  }

  return [@$super_attributes, sort { $a->{value} cmp $b->{value} } @ldap_attributes];
}

=head2 authenticate

=cut

sub authenticate {
  my ( $self, $username, $password ) = @_;
  my $timer_stat_prefix = called() . "." .  $self->{'id'};
  my $timer = pf::StatsD::Timer->new({'stat' => "${timer_stat_prefix}"});
  my $before; # will hold time before StatsD calls

  my ($connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();

  if (!defined($connection)) {
    return ($FALSE, $COMMUNICATION_ERROR_MSG);
  }
  my $result = $self->bind_with_credentials($connection);

  if ($result->is_error) {
    $logger->error("[$self->{'id'}] Unable to bind with $self->{'binddn'} on $LDAPServer:$LDAPServerPort");
    return ($FALSE, $COMMUNICATION_ERROR_MSG);
  }

  my $filter = "($self->{'usernameattribute'}=$username)";

  $result = do {
    my $timer = pf::StatsD::Timer->new({'stat' => "${timer_stat_prefix}.search"});
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
    my $timer = pf::StatsD::Timer->new({'stat' => "${timer_stat_prefix}.bind"});
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
  my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}"});
  my $connection;
  my $logger = Log::Log4perl::get_logger(__PACKAGE__);

  my @LDAPServers = split(/\s*,\s*/, $self->{'host'});
  # uncomment the next line if you want the servers to be tried in random order
  # to spread out the connections amongst a set of servers
  #@LDAPServers = List::Util::shuffle @LDAPServers;

  TRYSERVER:
  foreach my $LDAPServer ( @LDAPServers ) {
    # check to see if the hostname includes a port (e.g. server:port)
    my $LDAPServerPort;
    if ( $LDAPServer =~ /:/ ) {
        $LDAPServerPort = ( split(/:/,$LDAPServer) )[-1];
    }
    $LDAPServerPort //=  $self->{'port'} ;
    $connection = pf::LDAP->new(
        $LDAPServer,
        port       => $LDAPServerPort,
        timeout    => $self->{'connection_timeout'},
        encryption => $self->{encryption}
    );

    if (! defined($connection)) {
      $logger->warn("[$self->{'id'}] Unable to connect to $LDAPServer");
      next TRYSERVER;
    }

    # try TLS if required, return undef if it fails
    if ( $self->{'encryption'} eq TLS ) {
      my $mesg = $connection->start_tls();
      if ( $mesg->code() ) {
          $logger->error("[$self->{'id'}] ".$mesg->error());
          $pf::StatsD::statsd->increment("${timer_stat_prefix}.error.count" );
          return undef;
      }
    }

    $logger->debug("[$self->{'id'}] Using LDAP connection to $LDAPServer");
    return ( $connection, $LDAPServer, $LDAPServerPort );
  }
  # if the connection is still undefined after trying every server, we fail and return undef.
  if (! defined($connection)) {
    $logger->error("[$self->{'id'}] Unable to connect to any LDAP server");
    $pf::StatsD::statsd->increment("${timer_stat_prefix}.error.count" );
  }
  return undef;
}


=head2 match

    Overrided to add caching to avoid a hit to the database

=cut

sub match {
    my ($self, $params) = @_;
    my $timer_stat_prefix = called() . "." .  $self->{'id'};
    my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}"});
    if($self->is_match_cacheable) {
        return $self->cache->compute_with_undef([$self->id, $params], sub {
            $pf::StatsD::statsd->increment(called() . "." . $self->id. ".cache_miss.count" );
            return $self->match_with_object($params);
        });
    }
    return $self->match_with_object($params);
}

=head2 match_with_object

=cut

sub match_with_object {
    my ($self, $params) = @_;
    $self->preMatchProcessing();
    my $object = $self->get_user_object($params);
    return undef if !defined $object;
    my $rule = $self->match_first_rule($object, $params);
    $self->postMatchProcessing();
    return defined $rule ? $rule->{actions} : undef;
}

=head2 get_user_object

=cut

sub get_user_object {
    my ($self, $params) = @_;
    my $filter = $self->make_ldap_filter_for_user($params);
    if (!defined $filter) {
        my $logger = get_logger();
        $logger->error("$self->{id}: not enough information to look the user");
        return undef;
    }
    my $cached_connection = $self->_cached_connection;
    return undef if !defined $cached_connection;
    my ($connection, $LDAPServer, $LDAPServerPort) = @$cached_connection;
    my $result = $connection->search(
        base   => $self->{'basedn'},
        filter => $filter,
        scope  => $self->{'scope'},
    );
    my $count = $result->count;
    if ($count != 1) {
        my $logger = get_logger();
        $logger->error("$self->{id}: " . ($count ? "Too many results" : "could not find a user"));
        return undef;
    }
    return $result->pop_entry;
}

=head2 match_first_rule

Match the first rule that success

=cut

sub match_first_rule {
    my ($self, $object, $params) = @_;
    my %common_attributes_lookup = map { $_->{value} => undef } @{$self->common_attributes()};
    foreach my $rule ( @{$self->{'rules'}} ) {
        next if ( (defined($params->{'rule_class'})) && ($params->{'rule_class'} ne $rule->{'class'}) );
        if ($self->match_rule($rule, $object, $params, \%common_attributes_lookup)) {
            return $rule;
        }
    }
    return undef;
}

=head2 match_rule

Match the rule based parameters and user entry

=cut

sub match_rule {
    my ($self, $rule, $object, $params, $lookup) = @_;
    my $conditions = $rule->{conditions};
    #If this is a catch all return true
    return 1 if @$conditions == 0;
    #Split the conditions into common, ldap and member conditions
    my ($common_conditions, $ldap_conditions, $member_conditions) = part {
        exists $lookup->{$_->attribute} ? 0
        : $_->operator ne $Conditions::IS_MEMBER ? 1
        : 2
    } @$conditions;
    $common_conditions //= [];
    $ldap_conditions //= [];
    $member_conditions //= [];
    if ($rule->match eq $Rules::ANY) {
        return any { $self->match_condition($_, $params) } @$common_conditions
               || any { $self->match_ldap_condition($_, $object) } @$ldap_conditions
               || $self->match_member_conditions($object, $member_conditions, $rule->match);
    }
    return (@$common_conditions == 0 || all { $self->match_condition($_, $params) } @$common_conditions)
           && (@$ldap_conditions == 0 || all { $self->match_ldap_condition($_, $object) } @$ldap_conditions)
           && (@$member_conditions == 0 || $self->match_member_conditions($object, $member_conditions, $rule->match));
}

=head2 match_member_conditions

Match ldap group members

=cut

sub match_member_conditions {
    my ($self, $object, $member_conditions, $match) = @_;
    my $dn_search = escape_filter_value($object->dn);
    my $cached_connection = $self->_cached_connection;
    return undef if !defined $cached_connection;
    (my $connection, undef, undef) = @$cached_connection;
    if (!defined($connection)) {
      return 0;
    }
    if ($match eq $Rules::ANY ) {
        return any { $self->match_group_filter($connection, $object, $dn_search, $_) } @$member_conditions;
    }
    return all { $self->match_group_filter($connection, $object, $dn_search, $_) } @$member_conditions;
}

=head2 match_group_filter

Match based off group filter

=cut

sub match_group_filter {
    my ($self, $connection, $entry, $dn_search, $condition) = @_;
    my $value = escape_filter_value($condition->{'value'});
    my $attribute = escape_filter_value($entry->get_value($condition->{'attribute'}));
    # Search for any type of group definition:
    # - groupOfNames       => member (dn)
    # - groupOfUniqueNames => uniqueMember (dn)
    # - posixGroup         => memberUid (uid)
    my $filter = "(|(member=${dn_search})(uniqueMember=${dn_search})(memberUid=${attribute}))";
    my $result = $connection->search(
        base   => $value,
        filter => $filter,
        scope  => $self->{'scope'},
        attrs  => ['dn']
    );
    if ($result->is_error || $result->count != 1) {
        if ($result->is_error) {
            my $cached_connection = $self->_cached_connection;
            (undef, my $LDAPServer, my $LDAPServerPort) = @$cached_connection;
            $pf::StatsD::statsd->increment(called() . "." . $self->{'id'} . ".error.count");
            $logger->error( "[$self->{'id'}] Unable to execute search $filter from $value on $LDAPServer:$LDAPServerPort, we skip the condition (" . $result->error . ").");
        }
        return 0;
    }
    return 1;
}

=head2 match_ldap_condition

Match based off ldap conditions

=cut

sub match_ldap_condition {
    my ($self, $condition, $object) = @_;
    my $attribute = $condition->attribute;
    return any { $condition->matches($attribute, $_) } @{$object->get_value($attribute, asref => 1) // []};
}

=head2 make_ldap_filter_for_user

Make the ldap filter for the user

=cut

sub make_ldap_filter_for_user {
    my ($self, $params) = @_;
    my $username = $params->{username};

    # Handling stripped_username condition
    my $can_stripped_user_name = isenabled($self->{'stripped_user_name'});
    if ($can_stripped_user_name && defined($params->{'stripped_user_name'}) && $params->{'stripped_user_name'} ne '')
    {
        $username = $params->{'stripped_user_name'};
    }
    elsif ($can_stripped_user_name) {
        ($username, my $realm) = strip_username($params->{'username'});
    }

    if ($username) {
        my $usernameattribute = $self->usernameattribute;
        $username = escape_filter_value($username);
        return  "($usernameattribute=$username)";
    }
    elsif ($params->{'email'}) {
        my $email = escape_filter_value($params->{'email'});
        return "(|($self->{'email_attribute'}=$email)(proxyAddresses=smtp:$email)(mailLocalAddress=$email)(mailAlternateAddress=$email))";
    }
    return;
}

=head2 cache

    get the cache object

=cut

sub cache {
    return pf::CHI->new( namespace => 'ldap_auth');
}

=head2 is_match_cacheable

Checks to see if the match can be cached

=cut

sub is_match_cacheable {
    my ($self) = @_;
    #First check to see caching is disabled to see if we can exit quickly
    return 0 unless $self->cache_match;
    #Check rules for timed based operations return false first one found
    foreach my $rule (@{$self->{rules}}) {
        foreach my $condition (@{$rule->{conditions}}) {
            my $op = $condition->{operator};
            return 0 if $op eq $Conditions::IS_BEFORE || $op eq $Conditions::IS_AFTER;
        }
    }
    return $self->cache_match;
}

=head2 test

Test if we can bind and search to the LDAP server

=cut

sub test {
  my ($self) = @_;

  # Connect
  my ( $connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();

  if (! defined($connection)) {
    $logger->warn("[$self->{'id'}] Unable to connect to any LDAP server");
    return ($FALSE, "Can't connect to server");
  }

  # Bind
  my $result = $self->bind_with_credentials($connection);
  if ($result->is_error) {
    $logger->warn("[$self->{'id'}] Unable to bind with $self->{'binddn'} on $LDAPServer:$LDAPServerPort");
    return ($FALSE, ["Unable to bind to [_1] with these settings", $LDAPServer]);
  }

  # Search
  my $filter = "($self->{'usernameattribute'}=packetfence)";
  $result = $connection->search(
    base => $self->{'basedn'},
    filter => $filter,
    scope => $self->{'scope'},
    attrs => ['dn'],
    sizelimit => 1
  );

  if ($result->is_error) {
      $logger->warn("[$self->{'id'}] Unable to execute search $filter from $self->{'basedn'} on $LDAPServer:$LDAPServerPort: ".$result->error);
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
  my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}", sample_rate => 0.1});

  my $expression = $self->make_ldap_filter_for_user($params);

  if ($expression) {
      my @ldap_conditions;

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

=head2 bind_with_credentials

=cut

sub bind_with_credentials {
    my ($self,$connection) = @_;
    my $result;
    my $timer_stat_prefix = called() . "." .  $self->{'id'};
    my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}", sample_rate => 0.1});
    if ($self->{'binddn'} && $self->{'password'}) {
        $result = $connection->bind($self->{'binddn'}, password => $self->{'password'});
    } else {
        $result = $connection->bind;
    }
    if ($result->is_error) {
        $pf::StatsD::statsd->increment(called() . "." . $self->{'id'} . ".error.count" );
    }
    return $result;
}

=head2 search based on a attribute

=cut

sub search_attributes_in_subclass {
    my ($self, $username) = @_;
    my $timer_stat_prefix = called() . "." .  $self->{'id'};
    my $timer = pf::StatsD::Timer->new({ 'stat' => "${timer_stat_prefix}", sample_rate => 0.1});
    my ($connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();
    if (!defined($connection)) {
      return ($FALSE, $COMMUNICATION_ERROR_MSG);
    }
    my $result = $self->bind_with_credentials($connection);

    if ($result->is_error) {
      $logger->error("[$self->{'id'}] Unable to bind with $self->{'binddn'} on $LDAPServer:$LDAPServerPort");
      return ($FALSE, $COMMUNICATION_ERROR_MSG);
    }
    my $searchresult = $connection->search(
                  base => $self->{'basedn'},
                  filter => "($self->{'usernameattribute'}=$username)"
    );
    my $entry = $searchresult->entry();
    $connection->unbind();

    if (!$entry) {
        $logger->warn("Unable to locate user '$username'");
    }
    else {
         $logger->info("User: '$username' found in the directory");
    }

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
        $connection->unbind;
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

    my $result = $self->bind_with_credentials($connection);

    if ($result->is_error) {
        $logger->error("[$self->{'id'}] Unable to bind with $self->{'binddn'} on $LDAPServer:$LDAPServerPort");
        return undef;
    }
    $self->_cached_connection([$connection, $LDAPServer, $LDAPServerPort]);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

__PACKAGE__->meta->make_immutable;
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

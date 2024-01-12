=head1 COPYRIGHT

Copyright Alexander Clouter (https://github.com/jimdigriz)

Licence: https://github.com/jimdigriz/freeradius-oauth2-perl/blob/master/LICENSE

=cut

use lib qw(
  /usr/local/pf/lib_perl/lib/perl5
);

use strict;
use warnings;

use threads;
use threads::shared;

use HTTP::Status qw/is_client_error is_server_error/;
use JSON::PP;
use List::Util qw/reduce/;
use LWP::UserAgent;
use LWP::ConnCache;
use POSIX qw(setlocale LC_ALL);
use Time::Piece;

use Data::Dumper;

# https://wiki.freeradius.org/modules/Rlm_perl#logging is wrong...
use constant {
  L_AUTH  => 2,
  L_INFO  => 3,
  L_ERR   => 4,
  L_WARN  => 5,
  L_PROXY => 6,
  L_ACCT  => 7,
  L_DBG   => 16,
};

# https://wiki.freeradius.org/modules/Rlm_perl#return-codes
use constant {
  RLM_MODULE_REJECT    =>  0,  # immediately reject the request
  RLM_MODULE_FAIL      =>  1,  # module failed, don't reply
  RLM_MODULE_OK        =>  2,  # the module is OK, continue
  RLM_MODULE_HANDLED   =>  3,  # the module handled the request, so stop
  RLM_MODULE_INVALID   =>  4,  # the module considers the request invalid
  RLM_MODULE_USERLOCK  =>  5,  # reject the request (user is locked out)
  RLM_MODULE_NOTFOUND  =>  6,  # user not found
  RLM_MODULE_NOOP      =>  7,  # module succeeded without doing anything
  RLM_MODULE_UPDATED   =>  8,  # OK (pairs modified)
  RLM_MODULE_NUMCODES  =>  9,  # How many return codes there are
};

use vars qw/%RAD_PERLCONF %RAD_REQUEST %RAD_REPLY %RAD_CHECK/;

my @sups;
my %realms :shared;

# https://github.com/jimdigriz/freeradius-oauth2-perl/issues/13#issuecomment-728279207
$ENV{LC_ALL} = 'C' unless (defined($ENV{LC_ALL}));

# it would be nice to catch SIGHUP in the main thread to signal a refresh of
# the user/group lists but rlm_perl masks out the signal so we cannot

# BEGIN is run before anything starts so it would have been a good place
# to do initialising...but %RAD_PERLCONF is not yet populated so we cannot
#BEGIN {
#  &radiusd::radlog(L_DBG, 'oauth2 begin');
#}

# Fortunately, main calls seem to also run as a singleton before anything
# starts and %RAD_PERLCONF works, but we are unable to as for config{}:
# * "realm = ${realm}" does not work, looks to miss the realm keys or overwrites everything to 'realm'
# * "example.com = ${realm[example.com].oauth2}" produces an off-by-one with an extra empty string key
#  * using "example.com = { oauth2 = ${realm[example.com].oauth2} }" sort of works but throws a warning
#   * this does though make configuration harder for the end user
&radiusd::radlog(L_DBG, 'oauth2 global');
#&radiusd::radlog(L_DBG, 'oauth2 global: ' . Dumper \%RAD_PERLCONF);

# ...instead we opt for runtime checking:
# * %{config:...} throws a scary but ignorable ERROR if the key does not exist
# * we have to live with not being able to pre-populate before the first request
#  * besides xlat does not work in global so %{config:...} is not accessible here

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;
$ua->agent("freeradius-oauth2-perl/0.2 (+https://github.com/jimdigriz/freeradius-oauth2-perl; ${\$ua->_agent})");
$ua->conn_cache(LWP::ConnCache->new);
$ua->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());
if (defined($RAD_PERLCONF{debug}) && $RAD_PERLCONF{debug} =~ /^(?:1|true|yes)$/i) {
  &radiusd::radlog(L_INFO, 'debugging enabled, you will see the HTTPS requests in the clear!');

  sub handler {
    my $r = $_[0]->clone;
    $r->decode;
    &radiusd::radlog(L_DBG, $_)
      foreach split /\n/, $r->dump;
  }

  $ua->add_handler('request_send', \&handler);
  $ua->add_handler('response_done', \&handler);
}

# %{date:...} does not work :(
if ($^V ge v5.28) {
  Time::Piece->use_locale();
} else {
  warn "old version of Perl (pre-5.28) detected, non-English locale users must run FreeRADIUS with LC_ALL=C";
}
use constant RADTIME_FMT => '%b %e %Y %H:%M:%S %Z';
sub to_radtime {
  my ($s) = @_;
  return Time::Piece->strptime($s, '%Y-%m-%dT%H:%M:%SZ')->strftime(RADTIME_FMT);
}
sub worker {
  my $thr;
  my $running = 1;
  $SIG{'HUP'} = sub { print STDERR "worker supervisor SIGHUP\n"; $thr->kill('TERM') if (defined($thr)); };
  $SIG{'TERM'} = sub { print STDERR "worker supervisor SIGTERM\n"; $running = 0; $thr->kill('TERM') if (defined($thr)); };

  setlocale(LC_ALL, $ENV{LC_ALL});

  our ($realm, $discovery_uri, $client_id, $client_secret) = @_;
  our $ttl = int($RAD_PERLCONF{ttl} || 30);
  $ttl = 10 if ($ttl < 10);

  &radiusd::radlog(L_DBG, "oauth2 worker ($realm): supervisor started (tid=${\threads->tid()})");

  &radiusd::radlog(L_DBG, "oauth2 worker ($realm): fetching discovery document");

  my $r = $ua->get("${discovery_uri}/.well-known/openid-configuration");
  unless ($r->is_success) {
    &radiusd::radlog(L_ERR, "oauth2 worker ($realm): discovery failed: ${\$r->status_line}");
    die "discovery ($realm): ${\$r->status_line}";  # no cond_signal so we deadlock!
  }
  our $discovery = decode_json $r->decoded_content;

  my $pacing = 0;
  while (1) {
    $thr = async {
      my $running = 1;
      $SIG{'TERM'} = sub { print STDERR "worker SIGTERM\n"; $running = 0; };

      setlocale(LC_ALL, $ENV{LC_ALL});

      &radiusd::radlog(L_DBG, "oauth2 worker ($realm): started (tid=${\threads->tid()})");

      our ($authorization_var, $authorization_ttl);
      sub authorization {
        return $authorization_var if (defined($authorization_var) && $authorization_ttl > time());

        &radiusd::radlog(L_DBG, "oauth2 worker ($realm): fetching token");

        my $r = $ua->post($discovery->{token_endpoint}, [
          client_id => $client_id,
          client_secret => $client_secret,
          scope => 'https://graph.microsoft.com/.default',
          grant_type => 'client_credentials'
        ]);
        unless ($r->is_success) {
          &radiusd::radlog(L_ERR, "oauth2 worker ($realm): token failed: ${\$r->status_line}");
          die "token ($realm): ${\$r->status_line}" if (is_server_error($r->code));
          return;
        }

        my $token = decode_json $r->decoded_content;

        $authorization_var = "${\$token->{token_type}} ${\$token->{access_token}}";
        $authorization_ttl = time() + $token->{expires_in};

        return $authorization_var;
      }

      sub fetch {
        my ($purpose, $uri) = @_;

        my $r = $ua->get($uri, Authorization => &authorization(), Prefer => 'return=minimal', Accept => 'application/json');
        unless ($r->is_success) {
          if ($r->code == HTTP::Status::HTTP_UNAUTHORIZED) {
            $authorization_var = undef;
            return &fetch($purpose, $uri);
          } elsif ($r->code == HTTP::Status::HTTP_TOO_MANY_REQUESTS) {
            my $sleep = (int($r->header('Retry-After')) || 10) + 1;
            &radiusd::radlog(L_WARN, "oauth2 worker ($realm): $purpose throttled, sleeping for $sleep seconds");
            sleep($sleep);
            return &fetch($purpose, $uri);
          }

          &radiusd::radlog(L_WARN, "oauth2 worker ($realm): $purpose failed: ${\$r->status_line}");
          die "token ($realm): ${\$r->status_line}" if (is_server_error($r->code));

          return;
        }

        return decode_json $r->decoded_content;
      }

      sub walk {
        my ($purpose, $uri, $callback) = @_;

        my $delta;
        while (defined($uri)) {
          &radiusd::radlog(L_DBG, "oauth2 worker ($realm): $purpose page");

          my $data = &fetch($purpose, $uri);

          &$callback($data->{value});

          $delta = $data->{'@odata.deltaLink'};
          $uri = $data->{'@odata.nextLink'};
        }

        return $delta;
      }

      # delta queries can be seen as a database replication stream so we have to retain everything
      # unless explictly told that it can be deleted via @remove->reason->'deleted'
      my (%users, %groups);
      my $usersUri = 'https://graph.microsoft.com/v1.0/users/delta?$select=id,userPrincipalName,isResourceAccount,accountEnabled,lastPasswordChangeDateTime';
      my $groupsUri = 'https://graph.microsoft.com/v1.0/groups/delta?$select=id,displayName,members';
      while ($running) {
        &radiusd::radlog(L_INFO, "oauth2 worker ($realm): sync");

        &radiusd::radlog(L_DBG, "oauth2 worker ($realm): sync users");
        $usersUri = &walk('users', $usersUri, sub {
          my ($data) = @_;

#          print STDERR Dumper $data;

          foreach my $d (grep { ($_->{isResourceAccount} || JSON::PP::false) != JSON::PP::true } @$data) {
            my $id = $d->{id};
            if (exists($d->{'@removed'}) && $d->{'@removed'}{reason} eq 'deleted') {
              delete $users{$id};
            } else {
              my $r = exists($users{$id}) ? $users{$id} : shared_clone({});
              $users{$id} = $r;
              $r->{R} = exists($d->{'@removed'});
              $r->{n} = $d->{userPrincipalName} if (exists($d->{userPrincipalName}));
              $r->{e} = $d->{accountEnabled} == JSON::PP::true if (exists($d->{accountEnabled}));
              $r->{p} = to_radtime($d->{lastPasswordChangeDateTime}) if (exists($d->{lastPasswordChangeDateTime}));
            }
          }
        });

        &radiusd::radlog(L_DBG, "oauth2 worker ($realm): sync groups");
        $groupsUri = &walk('groups', $groupsUri, sub {
          my ($data) = @_;

#          print STDERR Dumper $data;

          foreach my $d (@$data) {
            my $id = $d->{id};
            if (exists($d->{'@removed'}) && $d->{'@removed'}{reason} eq 'deleted') {
              delete $groups{$id};
            } else {
              unless (exists($groups{$id})) {
                $groups{$id} = shared_clone({});
                $groups{$id}->{m} = shared_clone({});
              }
              my $r = $groups{$id};
              $r->{R} = exists($d->{'@removed'});
              $r->{n} = $d->{displayName} if (exists($d->{displayName}));
              foreach (@{$d->{'members@delta'}}) {
                if (exists($_->{'@removed'})) {  # always 'deleted'
                  delete $r->{m}->{$_->{id}};
                } else {
                  $r->{m}->{$_->{id}} = undef;
                }
              }
            }
          }
        });

#        print STDERR Dumper \%users;
#        print STDERR Dumper \%groups;

        &radiusd::radlog(L_DBG, "oauth2 worker ($realm): apply");
        my %db :shared;
        $db{t} = $discovery->{token_endpoint};
        $db{u} = shared_clone({});
        $db{u}{$users{$_}->{n}} = $users{$_}->{p}
          foreach grep { !$users{$_}->{R} && $users{$_}->{e} } keys %users;
        $db{g} = shared_clone({});
        foreach (grep { !$groups{$_}->{R} } keys %groups) {
          my @m = map { $users{$_}->{n} } grep { $users{$_}->{e} } keys %{$groups{$_}->{m}};
          $db{g}->{$groups{$_}->{n}} = shared_clone({ map { $_, undef } @m })
            if (scalar @m);
        }

        {
          lock(%{$realms{$realm}});
          %{$realms{$realm}} = %db;
          cond_signal(%{$realms{$realm}});
        }

        # successful run means we can reset the pacer
        $pacing = 0;

        my $sleep = int($ttl - ($ttl / 3) + rand(2 * $ttl / 3));
        &radiusd::radlog(L_INFO, "oauth2 worker ($realm): syncing in $sleep seconds");
        sleep($sleep);
      }
    };

    $thr->join();
    $thr = undef;

    last unless ($running);

    my $sleep = $pacing ** 2;
    &radiusd::radlog(L_WARN, "oauth2 worker ($realm): died, sleeping for $sleep seconds");
    sleep($sleep);
    $pacing++ if ($pacing < 10);
  }
}

sub authorize {
  &radiusd::radlog(L_DBG, 'oauth2 authorize');

  my $username = $RAD_REQUEST{'User-Name'};
  my $realm = $RAD_REQUEST{'Realm'};
  return RLM_MODULE_INVALID unless (defined($username) && defined($realm));

  {
    lock(%realms);
    unless (exists($realms{$realm})) {
      # discovery has already been checked that it exists in policy
      #  * %{xlat:...} does not work :(
      my $discovery_uri = &radiusd::xlat(&radiusd::xlat("%{config:realm[$realm].oauth2.discovery}"));

      # these should exist, if they do not...explode
      my $client_id = &radiusd::xlat("%{config:realm[$realm].oauth2.client_id}");
      my $client_secret = &radiusd::xlat("%{config:realm[$realm].oauth2.client_secret}");
      return RLM_MODULE_FAIL if ($client_id eq '' || $client_secret eq '');

      $realms{$realm} = shared_clone({});
      lock(%{$realms{$realm}});
      push @sups, threads->create(\&worker, $realm, $discovery_uri, $client_id, $client_secret);
      cond_wait(%{$realms{$realm}});
    }
  }

  my $state;
  {
    lock(%{$realms{$realm}});
    $state = $realms{$realm};
  }
#  print STDERR Dumper $state;

  return RLM_MODULE_NOTFOUND unless (exists($state->{u}{$username}));

  $RAD_REQUEST{'OAuth2-Group'} = reduce { push @$a, $b if (exists($state->{g}{$b}{$username})); $a; } [], keys %{$state->{g}};

  # technically should be done in authenticate, but we do it here as it would
  # create a race if the user was to update their password beteen here and there
  $RAD_CHECK{'OAuth2-Password-Last-Modified'} = $state->{u}{$username};

  $RAD_CHECK{'Auth-Type'} = 'oauth2';

  #$_->kill('HUP')->join() foreach @sups;

  return RLM_MODULE_UPDATED;
}

sub authenticate {
  &radiusd::radlog(L_DBG, 'oauth2 authenticate');

  my $username = $RAD_REQUEST{'User-Name'};
  my $realm = $RAD_REQUEST{'Realm'};

  my $state;
  {
    lock(%{$realms{$realm}});
    $state = $realms{$realm};
  }
  my $client_id = &radiusd::xlat("%{config:realm[$realm].oauth2.client_id}");
  my $client_secret = &radiusd::xlat("%{config:realm[$realm].oauth2.client_secret}");

  &radiusd::radlog(L_INFO, "oauth2 token");

  # $state->{t} is static so no race
  my $r = $ua->post($state->{t}, [
    client_id => $client_id,
    client_secret => $client_secret,
    scope => 'openid email',
    grant_type => 'password',
    username => $RAD_REQUEST{'User-Name'},
    password => $RAD_REQUEST{'User-Password'}
  ]);
  unless ($r->is_success) {
    &radiusd::radlog(L_ERR, "oauth2 token failed: ${\$r->status_line}");
    return RLM_MODULE_FAIL if (is_server_error($r->code));
    my $response = decode_json $r->decoded_content;
    my @e = ( 'Error: ' . $response->{'error'} );
    push @e, split /\r\n/ms, $response->{'error_description'}
      if (defined($response->{'error_description'}));
    $RAD_REPLY{'Reply-Message'} = \@e;
    return RLM_MODULE_REJECT;
  }

#  print STDERR Dumper decode_json $r->decoded_content;

  return RLM_MODULE_OK;
}

sub detach {
  &radiusd::radlog(L_DBG, 'oauth2 detach');

  # ...does not work
  #$_->kill('TERM')->join() foreach @sups;
}

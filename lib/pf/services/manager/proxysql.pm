package pf::services::manager::proxysql;

=head1 NAME

pf::services::manager::proxysql add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::proxysql

=cut

use strict;
use warnings;
use Moo;

use List::MoreUtils qw(uniq);

use pf::log;
use pf::util;
use pf::cluster;
use pf::constants qw($TRUE $FALSE);
use pf::config qw(
    %Config
    $management_network
);
use pf::file_paths qw(
    $generated_conf_dir
    $conf_dir
);

use Template;

extends 'pf::services::manager';

has '+name' => (default => sub { 'proxysql' } );

has '+shouldCheckup' => ( default => sub { 0 }  );

has 'proxysql_config_template' => (is => "rw" ,default => sub { "$conf_dir/proxysql.conf" });

has 'pxc_scheduler_handler_template' => (is => "rw" ,default => sub { "$conf_dir/config.toml" });

our $host_id = $pf::config::cluster::host_id;

tie our %clusters_hostname_map, 'pfconfig::cached_hash', 'resource::clusters_hostname_map';

our $DB_Config;

tie %$DB_Config, 'pfconfig::cached_hash', 'resource::Database';

=head2 compute_tier_connections

Work out the per-tier C<max_connections> for one tenant from the capacity of the
database it shares.

Takes a hashref of inputs and a hashref of relative tier weights, and returns a
hashref of tier name to connection count. Plug your own numbers into C<%capacity>
in C<generateConfig> and regenerate; nothing else needs editing.

Inputs:

=over

=item * C<db_max_connections> -- what the shared database will accept. Cloud SQL
for MySQL allows 4000 on every machine type except db-f1-micro and db-g1-small,
each costing the instance 1-4 MB. Google does not publish the per-tier table;
4000 is the figure consistently reported in the field. Confirm yours with
C<SHOW VARIABLES LIKE 'max_connections'>.

=item * C<tenants> -- how many PF instances share that database.

=item * C<reserve_pct> -- percentage held back for admin sessions, monitoring,
replication and migrations, so tenants never consume the whole ceiling.

=item * C<min_per_tier> -- floor applied after the split, so a small budget or a
light weight cannot reduce a tier to zero.

=back

The arithmetic:

    usable = db_max_connections * (100 - reserve_pct) / 100
    budget = usable / tenants                       # one tenant's total
    tier   = budget * weight / sum(weights)         # split by weight, floored

Any remainder left by the flooring is given to the heaviest tier, so the tiers
add up to the budget rather than quietly losing connections to rounding.

Worked example, with the values shipped below:

    4000 * 0.80 = 3200 usable; 3200 / 120 tenants = 26 per tenant
    weights 2:2:3:5 (sum 12) -> small 4, radius 4, medium 6, large 10
    remainder 2 -> large 12
    total 26

These are ceilings, not reservations: ProxySQL opens backend connections on
demand and C<mysql-free_connections_pct> keeps only a small idle pool, so the
fleet only approaches the ceiling if many tenants peak at once.

=cut

sub compute_tier_connections {
    my ($capacity, $weights) = @_;

    my @names = keys %$weights;
    return {} unless @names;

    my $total_weight = 0;
    $total_weight += $_ for values %$weights;
    return {} unless $total_weight > 0;

    my (undef, $budget) = tier_budget($capacity);
    my $floor = $capacity->{min_per_tier};

    # Every tier needs at least the floor, so a budget that cannot cover all of
    # them together has no valid split. Say so rather than handing back tiers
    # that add up to more than the database allows -- the caller falls back to
    # the untiered single-hostgroup path.
    return {} if $budget < $floor * scalar(@names);

    my (%conns, $assigned);
    $assigned = 0;
    for my $name (@names) {
        my $n = int($budget * $weights->{$name} / $total_weight);
        $conns{$name} = $n;
        $assigned += $n;
    }

    # Give the flooring remainder to the heaviest tier rather than losing it.
    my @heaviest_first = sort { $weights->{$b} <=> $weights->{$a} || $a cmp $b } @names;
    $conns{$heaviest_first[0]} += $budget - $assigned if $budget > $assigned;

    # Raise anything the weights left below the floor, paying for it out of the
    # largest tiers so the total still matches the budget. The guard above
    # guarantees there is enough to go round: the tiers sum to the budget, and
    # budget - floor*n >= 0 is exactly the spare above the floors.
    my $deficit = 0;
    for my $name (@names) {
        next if $conns{$name} >= $floor;
        $deficit += $floor - $conns{$name};
        $conns{$name} = $floor;
    }
    for my $name (sort { $conns{$b} <=> $conns{$a} || $a cmp $b } @names) {
        last if $deficit <= 0;
        my $spare = $conns{$name} - $floor;
        next if $spare <= 0;
        my $take = ($spare < $deficit) ? $spare : $deficit;
        $conns{$name} -= $take;
        $deficit      -= $take;
    }

    return \%conns;
}

=head2 tier_budget

Return C<(usable, budget)> for a capacity plan: the connections left after the
reserve, and one tenant's share of them. compute_tier_connections splits the
budget, and generateConfig prints both in the generated file, so the two can
never disagree.

=cut

sub tier_budget {
    my ($capacity) = @_;
    my $usable = int($capacity->{db_max_connections} * (100 - $capacity->{reserve_pct}) / 100);
    my $budget = int($usable / $capacity->{tenants});
    return ($usable, $budget);
}

=head2 tier_route_patterns

The ProxySQL C<match_pattern> of each routed tier, as ProxySQL sees it (before
the libconfig escaping generateConfig adds). The catch-all takes whatever none
of these match.

=over

=item * C<large> -- the auth hot path: httpd.aaa (RADIUS authorize and its
chi_cache reads, decorated through pf::CHI::db), pfacct, and pfconfig, whose
C<keyed> reads stall every config client, auth included, while they wait.

=item * C<medium> -- frontend and API.

=item * C<radius> -- FreeRADIUS rlm_sql, which offers no hook to prepend the
routing remark, so it is matched on the statements it sends: the C<acct_*>
procedures and the rlm_sql tables (raddb/mods-config/sql/main/mysql/queries.conf,
conf/radiusd/sql.conf.example). Only SELECT/INSERT/UPDATE/CALL qualify, so an
undecorated C<ALTER> or C<DELETE> on radacct from a script falls to the
catch-all instead of taking RADIUS connections. Decorated queries start with
C</*>, so they can never match it.

=back

The tag charset allows C<.>, C<-> and C</>, which are regex metacharacters,
hence the escaping. A tag ends either with C<" */"> or with C<":E<lt>unitE<gt>">,
so C<[ :]> after a service name matches both while preventing prefix
collisions (pfhttpd vs pfhttpd2).

=cut

sub tier_route_patterns {
    my $rlm_sql_tables = join('|', qw(
        radacct radius_nas radius_audit_log radpostauth
        radcheck radreply radgroupcheck radgroupreply radusergroup
    ));
    return {
        large  => '^/\* pf:(httpd\.aaa|pfacct|pfconfig)[ :]',
        medium => '^/\* pf:((pfhttpd|httpd\.webservices|pfperl-api)[ :]|pfqueue[^:]*:api )',
        radius => '(?s)^\s*(CALL\s+acct_(start|update|stop)\b'
                . '|(SELECT|INSERT|UPDATE)\b.*\b(' . $rlm_sql_tables . ')\b'
                . '|SELECT\b.*\bFROM\s+password\s+JOIN\s+activation\b)',
    };
}

=head2 template_has_tier_placeholders

Whether the proxysql.conf template carries the placeholders the SaaS tiers
need. conf/proxysql.conf ships with each release, but a locally modified copy is
kept on upgrade (rpm %config(noreplace), dpkg conffile), and rendering tiers
into a pre-tier template would write the tier hostgroups without their query
rules, sending everything to the catch-all.

=cut

sub template_has_tier_placeholders {
    my ($path) = @_;
    open(my $fh, '<', $path) or return 0;
    local $/;
    my $content = <$fh>;
    close($fh);
    return $content =~ /\[%\s*mysql_cloud_variables\s*%\]/ ? 1 : 0;
}

sub generateConfig {
    my ($self,$quick) = @_;
    my $tt = Template->new(ABSOLUTE => 1);

    my $logger = get_logger();
    my ($package, $filename, $line) = caller();

    my %tags;
    my $single_server = 0;
    $tags{'template'} = $self->proxysql_config_template;
    $tags{'geoDB'} = $FALSE;
    $tags{'replication'} = $FALSE;
    $tags{'mysql_servers'} = "";
    $tags{'mysql_replication_hostgroups'} = "";
    $tags{'mysql_query_rules'} = "";
    $tags{'mysql_monitor_variables'} = "";
    $tags{'mysql_ssl_p2s_capath'} = "";  # initialized empty; set below only when SSL cacert is configured
    $tags{'database'} = $DB_Config->{db};

    # Standardized hostgroups used everywhere:
    #   HG 10 = writer
    #   HG 30 = reader
    my $writer_hostgroup  = 10;
    my $reader_hostgroup  = 30;
    my $has_reader_split  = 0;  # flag: only generate query rules / replication hostgroups when we actually have a reader HG

    # SaaS single-backend capacity tiers.
    #
    # In SaaS, 100+ tenants share one Cloud SQL instance, so each must cap what
    # it can take, without impacting authentication. max_connections is a
    # mysql_servers attribute (not a hostgroup one), so each tier is a hostgroup
    # holding its own row pointing at the SAME backend host:port with its own
    # cap; the query rule that routes to it carries the query timeout. Queries
    # are sorted into tiers by the routing remark (/* pf:<service>[:<unit>] */,
    # see pf::db::dbi and go/db/sqlcomment) and, for FreeRADIUS, by the
    # statements rlm_sql sends; see tier_route_patterns. The defined tiers carry
    # the time-critical traffic; the catch-all is the bounded low-priority bucket.
    #
    # Tiers only apply under PF_SAAS (the same flag pf::UnifiedApi::Controller::
    # SystemSummary reports). On-prem the database belongs to the deployment, and
    # a single backend keeps the untiered layout.
    #
    # The connection caps are NOT hand-picked -- they are derived from the
    # numbers in %capacity below by compute_tier_connections(). To retune,
    # change those numbers and regenerate; see that sub's documentation.
    #
    # Timeouts are log-spaced downward from the 360s network timeout, which is
    # the ceiling: large keeps it, medium and catch-all are progressively clamped.
    my $medium_hostgroup = 11;
    my $large_hostgroup  = 12;
    my $radius_hostgroup = 13;

    my $is_saas = isenabled($ENV{PF_SAAS});

    # Cloud SQL for MySQL allows 4000 connections on every machine type except
    # db-f1-micro and db-g1-small. Google does not publish the per-tier table;
    # confirm with SHOW VARIABLES LIKE 'max_connections'.
    my %capacity = (
        db_max_connections => 4000,
        tenants            => 120,  # 100+ today, sized for growth
        reserve_pct        => 20,   # held back for admin, monitoring, replication, migrations
        min_per_tier       => 2,    # floor, so a tier can never be starved to nothing
        frontend_ratio     => 8,    # frontend sessions allowed per backend connection
        frontend_max       => 2048, # ceiling on that, matching ProxySQL's own default
        user_pct           => 75,   # per-user share of the frontend cap
    );

    # Relative share of a tenant's budget. Large carries RADIUS authentication
    # and accounting, medium the frontend and API, and the remaining two are
    # FreeRADIUS rlm_sql and the catch-all.
    my %tier_weight = (
        small  => 2,
        radius => 2,
        medium => 3,
        large  => 5,
    );

    my %tier = (
        small  => { hg => $writer_hostgroup, timeout_ms => 40_000  },
        radius => { hg => $radius_hostgroup, timeout_ms => 40_000  },
        medium => { hg => $medium_hostgroup, timeout_ms => 120_000 },
        large  => { hg => $large_hostgroup,  timeout_ms => 360_000 },
    );
    my $cloud_tiers = 0;  # flag: SaaS single-backend tier mode, generate the tier rules

    # Frontend connection cap (mysql_variables max_connections), i.e. sessions
    # from PF services into ProxySQL. ProxySQL's own default; tier mode lowers it.
    $tags{'frontend_max_connections'} = 2048;
    $tags{'mysql_cloud_variables'} = "";
    $tags{'mysql_user_max_connections'} = "";

    # Monitor and shunning variables — ensure reliable auto-detection of dead servers:
    #   monitor_ping_max_failures=3  → SHUNNED after 3 missed pings (~6 sec with 2s interval)
    #   shun_recovery_time_sec=60    → stays shunned 60s before retry
    #   shun_on_failures=3           → app connection failures before shunning
    #   timeouts raised to 3000ms    → avoids false positives from tight timeouts
    # NOTE: proxysql.conf mysql_variables block does NOT use the 'mysql-' prefix.
    # These variable names are used as-is inside mysql_variables = { } in the template.
    # The [% mysql_monitor_variables %] tag should be placed INSIDE the mysql_variables
    # block in proxysql.conf, alongside [% monitor %] (username/password).
    $tags{'mysql_monitor_variables'} = << "EOT";
    monitor_enabled=1
    monitor_connect_timeout=3000
    monitor_ping_timeout=3000
    monitor_read_only_timeout=2000
    monitor_ping_interval=2000
    monitor_connect_interval=3000
    monitor_read_only_interval=1000
    monitor_ping_max_failures=3
    monitor_read_only_max_timeout_count=3
    shun_on_failures=3
    shun_recovery_time_sec=60
    connect_retries_on_failure=5
    connect_timeout_server=3000
    connect_timeout_server_max=10000
EOT

    $tags{'monitor'} = << "EOT";
    monitor_username="$DB_Config->{user}"
    monitor_password="$DB_Config->{pass}"
EOT

    # NOTE: mysql_users is generated after the backend branching below, since the
    # per-user frontend cap depends on whether we ended up in cloud tier mode.
    # transaction_persistent=1 keeps a transaction on the hostgroup it started
    # in: with query rules (tiers or a reader split) the statements of one
    # transaction would otherwise be routed one at a time to different
    # hostgroups, so different backend connections, outside the transaction.

    my $i = 100;
    my $database_proxysql = $pf::config::Config{database_proxysql};
    my $port = $database_proxysql->{port} || 3306;

    if (isenabled($database_proxysql->{status})) {
        my $cacert = $database_proxysql->{cacert};
        if ($cacert) {
            $tags{'mysql_ssl_p2s_capath'} = << "EOT";
    mysql-ssl_p2s_capath = "$conf_dir/";
    mysql-ssl_p2s_ca = "$cacert";
EOT
        }

        my $backends_str = $database_proxysql->{backends} || '';
        my @backends = grep { $_ ne '' } map { s/^\s+|\s+$//gr } split(/,/, $backends_str);
        my $ssl = $cacert ? 1 : 0;

        if (scalar(@backends) <= 1) {
            $single_server = 1;
            my $backend = $backends[0] // '';
            if ($is_saas) {
                my $tier_conns = compute_tier_connections(\%capacity, \%tier_weight);
                if ((keys %$tier_conns) != (keys %tier)) {
                    # The budget cannot seat every tier at its floor, i.e.
                    # %capacity has been retuned past what the tiers can express.
                    $logger->error(
                        "proxysql capacity plan cannot seat " . scalar(keys %tier) . " tiers at "
                        . "min_per_tier=$capacity{min_per_tier} from $capacity{db_max_connections} "
                        . "connections shared by $capacity{tenants} tenants; falling back to a single hostgroup");
                } elsif (!template_has_tier_placeholders($self->proxysql_config_template)) {
                    $logger->error(
                        $self->proxysql_config_template . " predates the capacity tiers (no mysql_cloud_variables "
                        . "placeholder), most likely a locally modified copy kept on upgrade; falling back to a "
                        . "single hostgroup. Merge proxysql.conf.example into it to enable the tiers.");
                } else {
                    $tier{$_}{max_connections} = $tier_conns->{$_} for keys %tier;
                    $cloud_tiers = 1;
                }
            }

            if (!$cloud_tiers) {
                # On-prem, or a SaaS plan that cannot be applied (logged above):
                # one hostgroup and no rules.
                $tags{mysql_servers} .= << "EOT";
    { address="$backend" , port=$port , hostgroup=$writer_hostgroup, max_connections=1000, weight=100, use_ssl=$ssl },
EOT
            } else {
                # The one backend is registered once per capacity tier (same
                # address:port, different hostgroup) so each tier gets its own
                # connection cap. Queries reach the right tier via the rules
                # generated further down. The capacity plan is recorded in the
                # generated file so an operator can see where the numbers came from.
                my ($usable, $budget) = tier_budget(\%capacity);
                $tags{mysql_servers} .= sprintf(
                    "    # capacity plan: %d ceiling - %d%% reserved = %d usable, / %d tenants = %d per tenant\n",
                    $capacity{db_max_connections}, $capacity{reserve_pct}, $usable, $capacity{tenants}, $budget);
                foreach my $name (qw(small radius medium large)) {
                    my $t = $tier{$name};
                    $tags{mysql_servers} .= << "EOT";
    { address="$backend" , port=$port , hostgroup=$t->{hg}, max_connections=$t->{max_connections}, weight=100, use_ssl=$ssl }, # $name tier (weight $tier_weight{$name})
EOT
                }

                # Frontend sessions (PF services into ProxySQL) never reach the
                # database: multiplexing lends a pooled backend connection out
                # only for the duration of a statement, so they can safely
                # outnumber the backend pool. This cap is a leak guard, not a
                # database protection -- sized as a multiple of the backend
                # budget, since a frontend count far above that ratio means
                # something is holding sessions it should have returned.
                my $frontend_max = $budget * $capacity{frontend_ratio};
                $frontend_max = $capacity{frontend_max} if $frontend_max > $capacity{frontend_max};
                $tags{'frontend_max_connections'} = $frontend_max;

                # Connection hygiene for the shared Cloud SQL instance. These are
                # applied here (not via the admin interface) because the container
                # starts proxysql with --initial, which re-reads this generated file
                # and discards any runtime/on-disk changes.
                # auto_increment_delay_multiplex defaults to 5, which pins a backend
                # connection for 5 queries after every auto-increment INSERT -- a
                # constant tax at PF's insert rate. Safe to disable: the only two
                # last_insert_id callers (pf::security_event, pf::Survey) read
                # mysql_insertid from the OK packet, and nothing issues
                # SELECT LAST_INSERT_ID() as a separate statement.
                $tags{'mysql_cloud_variables'} = << "EOT";
    wait_timeout=300000
    connection_max_age_ms=300000
    auto_increment_delay_multiplex=0
EOT
                # Per-user frontend cap, kept below the global one above so that it is
                # the binding limit: a leak then fails as "max_connections exceeded"
                # for this user rather than as a generic frontend rejection, and the
                # spare headroom covers a second account (migration, admin) without
                # reconfiguring. Unlike the backend caps -- where ProxySQL holds the
                # query until a pooled connection frees -- exceeding this is an
                # intentional reject: it is the noisy-neighbour throttle.
                my $user_max = int($frontend_max * $capacity{user_pct} / 100);
                $tags{'mysql_user_max_connections'} = ", max_connections = $user_max";
            }
        } else {
            $single_server = 0;
            $tags{'replication'} = $TRUE;
            $has_reader_split = 1;

            # First backend = READ/WRITE
            #   → HG 10 (writer) weight=100
            #   → HG 30 (reader) weight=50 as fallback only
            #      (replicas have higher weight and are preferred for reads)
            #   → if all pure readers go down, writer can still serve reads ✅
            my $writer = $backends[0];
            $tags{mysql_servers} .= << "EOT";
    { address="$writer" , port=$port , hostgroup=$writer_hostgroup, max_connections=1000, weight=100, use_ssl=$ssl },
    { address="$writer" , port=$port , hostgroup=$reader_hostgroup, max_connections=1000, weight=50, use_ssl=$ssl },
EOT

            # Remaining backends = READ ONLY → HG 30 only
            # weight=99,98... so first server is preferred for reads
            # On failover: promoted replica sets read_only=0
            # → ProxySQL auto-moves it to HG 10 via mysql_replication_hostgroups
            my $r = 99;
            foreach my $backend (@backends[1..$#backends]) {
                $tags{mysql_servers} .= << "EOT";
    { address="$backend" , port=$port , hostgroup=$reader_hostgroup, max_connections=1000, weight=$r, use_ssl=$ssl },
EOT
                $r--;
            }
        }
    } elsif (pf::cluster::getWriteDB()) {
        $tags{'geoDB'} = $TRUE;
        my @mysql_write_backend = pf::cluster::getWriteDB();
        my @mysql_read_backend = pf::cluster::getReadDB();
        $has_reader_split = 1;

        foreach my $mysql_back (@mysql_write_backend) {
            # Writers go to HG 10 AND HG 30 as fallback if all readers go down
            # weight=50 in HG 30 so readers (weight=100) are always preferred for reads
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=$writer_hostgroup, max_connections=1000, weight=$i },
    { address="$mysql_back" , port=$port , hostgroup=$reader_hostgroup, max_connections=1000, weight=50 },
EOT
            $i--;
        }
        $i = 100;
        # HG 30 (reader)
        foreach my $mysql_back (@mysql_read_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=$reader_hostgroup, max_connections=1000, weight=$i },
EOT
            $i--;
        }
    } elsif (($database_proxysql->{scheduler} // '') eq 'default') {
        my @mysql_backend;

        @mysql_backend = map { $_->{management_ip} } pf::cluster::mysql_servers();

        foreach my $mysql_back (@mysql_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=$writer_hostgroup, max_connections=1000, weight=$i },
EOT
            $i--;
        }
    } else {
        my @mysql_backend;

        @mysql_backend = map { $_->{management_ip} } pf::cluster::mysql_servers();
        $has_reader_split = 1;

        foreach my $mysql_back (@mysql_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=$writer_hostgroup, max_connections=1000, weight=$i },
EOT
            $i--;
        }
        my $j = 101 - @mysql_backend;
        # HG 30 (reader)
        # FIX: was "next if ($j = ...)" which is always true — $j++ was never reached
        foreach my $mysql_back (@mysql_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=$reader_hostgroup, max_connections=1000, weight=$j },
EOT
            $j++;
        }
        $i = 100;
        foreach my $mysql_back (@mysql_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=810, max_connections=1000, weight=$i },
EOT
            $i--;
        }
        $j = 101 - @mysql_backend;
        foreach my $mysql_back (@mysql_backend) {
            $tags{'mysql_servers'} .= << "EOT";
    { address="$mysql_back" , port=$port , hostgroup=830, max_connections=1000, weight=$j },
EOT
            $j++;
        }
    }

    $tags{'mysql_users'} = << "EOT";
        { username = "$DB_Config->{user}", password = "$DB_Config->{pass}", default_hostgroup = $writer_hostgroup, transaction_persistent = 1, active = 1$tags{'mysql_user_max_connections'} },
EOT

    $tags{'scheduler'} = $TRUE;
    $tags{'scheduler'} = $FALSE if (($database_proxysql->{scheduler} // '') ne 'default');
    $tags{'scheduler'} = $FALSE if ($tags{'replication'});

    my @mysql_servers = pf::cluster::mysql_servers();

    $tags{'single_server'} = $single_server || (scalar(@mysql_servers) == 1);

    # Generate mysql_replication_hostgroups using standardized HG 10/30
    # read_only=0 → server auto-moved to HG 10 (writer)
    # read_only=1 → server auto-moved to HG 30 (reader)
    # Only generated when we actually have a reader split
    #
    # IMPORTANT: the proxysql.conf template MUST reference [% mysql_replication_hostgroups %]
    # instead of a hardcoded mysql_replication_hostgroups block, otherwise this tag is ignored.
    if ($has_reader_split) {
        # mysql_replication_hostgroups tells ProxySQL to monitor read_only on ALL servers
        # in both writer_hostgroup and reader_hostgroup.
        # Automatic failover works as follows:
        #   - ProxySQL checks read_only every monitor_read_only_interval ms
        #   - If a server in HG 30 becomes read_only=0 (promoted by Cloud SQL or DBA):
        #       → ProxySQL automatically moves it to HG 10 (writer) ✅
        #   - If the current writer becomes read_only=1 (demoted):
        #       → ProxySQL automatically moves it to HG 30 (reader) ✅
        #   - active=1 ensures the monitor thread is running for this hostgroup pair
        $tags{'mysql_replication_hostgroups'} = << "EOT";
mysql_replication_hostgroups =
(
    { writer_hostgroup=$writer_hostgroup, reader_hostgroup=$reader_hostgroup, check_type="read_only", active=1, comment="Replication RW Split - auto failover via read_only check" }
)
EOT
    }

    # Generate mysql_query_rules:
    #   rule 1 — SELECT ... FOR UPDATE     → HG 10 (writer always, locks rows)
    #   rule 2 — SELECT @@global.read_only → HG 10 (writer)
    #   rule 3 — SELECT on processlist or performance_schema → HG 10 (writer)
    #            netdata's mysql collector runs SET SESSION sql_log_off and
    #            SET SESSION slow_query_log, which lock its session to HG 10;
    #            without this rule its processlist SELECT (and the
    #            performance_schema SELECTs of newer netdata functions) match
    #            rule 4 → HG 30 and ProxySQL rejects them with error 9006
    #            (locked to hostgroup). (?s) lets .* cross the newlines of
    #            those multi-line queries
    #   rule 4 — SELECT                    → HG 30 (readers preferred)
    #            writer is also in HG 30 (weight=50) only as fallback
    #            if all pure readers go down
    #   rule 5 — catch-all                 → HG 10 in normal mode
    #            scheduler rewrites 1,2,5 during degraded mode
    #            (rule 3 is deliberately NOT rewritten: a SELECT still works
    #            on a read-only writer, and replace_pattern would break it)
    # Only generated when we actually have a reader split, and never for a
    # single server (the template used to enforce the latter with an
    # "UNLESS single_server" wrapper; it lives here now because cloud tier mode
    # is single_server yet still needs rules).
    #
    # IMPORTANT: the proxysql.conf template MUST reference [% mysql_query_rules %]
    # instead of a hardcoded mysql_query_rules block, otherwise this tag is ignored.
    # Also ensure rule_ids here do not conflict with any remaining rules in the template.
    if ($has_reader_split && !$tags{'single_server'}) {
        $tags{'mysql_query_rules'} = << "EOT";
mysql_query_rules =
(
    {
        rule_id=1,
        active=1,
        match_pattern="^SELECT.*FOR UPDATE",
        destination_hostgroup=$writer_hostgroup,
        apply=1,
        comment="SELECT FOR UPDATE goes to writer"
    },
    {
        rule_id=2,
        active=1,
        match_pattern="^SELECT \@\@global[.]read_only",
        destination_hostgroup=$writer_hostgroup,
        apply=1,
        comment="SELECT global.read_only goes to writer"
    },
    {
        rule_id=3,
        active=1,
        match_pattern="(?s)^SELECT.*(information_schema[.]processlist|performance_schema[.])",
        destination_hostgroup=$writer_hostgroup,
        apply=1,
        comment="processlist and performance_schema SELECTs stay on writer — netdata session is locked to HG $writer_hostgroup by SET SESSION"
    },
    {
        rule_id=4,
        active=1,
        match_pattern="^SELECT",
        destination_hostgroup=$reader_hostgroup,
        apply=1,
        comment="SELECT goes to readers — writer is also in HG $reader_hostgroup as fallback"
    },
    {
        rule_id=5,
        active=1,
        match_pattern=".*",
        destination_hostgroup=$writer_hostgroup,
        apply=1,
        comment="Catch-all traffic goes to writer in normal mode; scheduler rewrites in degraded mode"
    }
)
EOT
    } elsif ($cloud_tiers) {
        # Capacity tiers for the shared SaaS database; the patterns and what each
        # tier carries are documented on tier_route_patterns.
        #
        # These must use match_pattern: match_digest strips comments (see
        # pf::db::dbi). Backslashes are doubled here because libconfig unescapes
        # one level.
        #
        # Rules are evaluated by ascending rule_id and apply=1 stops at the first
        # match, so the catch-all clamp must come last. rule_ids start at 21 to
        # stay clear of 1..5 (1,2,5 rewritten at runtime by proxysql-read-only-handler.sh)
        # and of the legacy 100..400 rules.
        my %pattern = %{ tier_route_patterns() };
        s/\\/\\\\/g for values %pattern;
        my $large_pattern  = $pattern{large};
        my $medium_pattern = $pattern{medium};
        my $radius_pattern = $pattern{radius};
        $tags{'mysql_query_rules'} = << "EOT";
mysql_query_rules =
(
    {
        rule_id=21,
        active=1,
        match_pattern="$large_pattern",
        destination_hostgroup=$tier{large}{hg},
        timeout=$tier{large}{timeout_ms},
        apply=1,
        comment="Large capacity tier: RADIUS auth, accounting and pfconfig"
    },
    {
        rule_id=22,
        active=1,
        match_pattern="$medium_pattern",
        destination_hostgroup=$tier{medium}{hg},
        timeout=$tier{medium}{timeout_ms},
        apply=1,
        comment="Medium capacity tier: frontend and API traffic"
    },
    {
        rule_id=23,
        active=1,
        match_pattern="$radius_pattern",
        destination_hostgroup=$tier{radius}{hg},
        timeout=$tier{radius}{timeout_ms},
        apply=1,
        comment="RADIUS tier: undecorated FreeRADIUS rlm_sql traffic, matched by statement"
    },
    {
        rule_id=24,
        active=1,
        match_pattern=".",
        destination_hostgroup=$tier{small}{hg},
        timeout=$tier{small}{timeout_ms},
        apply=1,
        comment="Catch-all tier: clamps connections and query time for everything else"
    }
)
EOT
    }

    $tags{'mysql_pf_user'} = $DB_Config->{user};
    $tags{'mysql_pf_user'} =~ s/"/\\"/g;
    $tags{'mysql_pf_pass'} = $DB_Config->{pass};
    $tags{'mysql_pf_pass'} =~ s/"/\\"/g;
    $tt->process($self->proxysql_config_template, \%tags, "$generated_conf_dir/".$self->name.".conf") or die $tt->error();
    $tt->process($self->pxc_scheduler_handler_template, \%tags, "$generated_conf_dir/config.toml") or die $tt->error();

    return 1;
}

sub isManaged {
    my ($self) = @_;
    my $name = $self->name;
    if (isenabled($pf::config::Config{'services'}{$name})) {
        return $cluster_enabled;
    } else {
        return 0;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

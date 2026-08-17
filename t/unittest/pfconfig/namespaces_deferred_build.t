#!/usr/bin/perl

=head1 NAME

pfconfig namespaces deferred build

=cut

=head1 DESCRIPTION

Regression test for the pfconfig reload memory leak.

The manager constructs every namespace on each expire (via get_namespace) just
to read its child_resources. A handful of resource namespaces used to run a
full config build() inside init(), so each C<pfcmd pfconfig reload> rebuilt
those configs and leaked memory (the tied pf::IniFiles reads never fully free).

Construction (new -> init) must therefore stay cheap: the heavy build work must
happen only in build(). This test asserts init() does not populate the
build-only attributes.

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use setup_test_config;
}

use Test::More tests => 24;
use Test::NoWarnings;

use_ok("pfconfig::namespaces::resource::network_config");
use_ok("pfconfig::namespaces::resource::accounting_triggers");
use_ok("pfconfig::namespaces::resource::bandwidth_expired_security_events");

# A cheap init() must not touch the cache, so a bare fake cache is enough here.
my $cache = bless {}, "pfconfig::manager";

my $nc = pfconfig::namespaces::resource::network_config->new($cache, "");
ok(
    !exists $nc->{cluster_resource} && !exists $nc->{config_pf},
    "network_config init() does not build its dependencies (deferred to build)"
);

my $at = pfconfig::namespaces::resource::accounting_triggers->new($cache);
ok(
    !exists $at->{_engine},
    "accounting_triggers init() does not construct the SecurityEvent engine"
);

my $bw = pfconfig::namespaces::resource::bandwidth_expired_security_events->new($cache);
ok(
    !exists $bw->{_engine},
    "bandwidth_expired_security_events init() does not construct the SecurityEvent engine"
);

=head2 config namespaces declare their defaults file, they do not build it

A config subclass layering its file over a defaults file must set import_file and
let pfconfig::namespaces::config::build materialise the pf::IniFiles. Building it
in init() put an IniFiles -- the thing that retains memory once read -- on every
construction, which is what leaked per reload.

=cut

use_ok("pfconfig::namespaces::config::Report");
use_ok("pfconfig::namespaces::config::Cron");

use_ok("pfconfig::namespaces::config::TLS");

for my $case (["config::Report", "Report"], ["config::Cron", "Cron"], ["config::TLS", "TLS"]) {
    my ($label, $short) = @$case;
    my $ns = "pfconfig::namespaces::config::$short"->new($cache);

    ok(defined $ns->{import_file}, "$label init() declares its defaults file via import_file");
    ok(
        !defined $ns->{added_params} || !defined $ns->{added_params}{-import},
        "$label init() does not build the -import IniFiles"
    );
    isa_ok($ns->import_config(), "pf::IniFiles", "$label import_config() builds it on demand");
}

# import_params has to reach the IniFiles, or a namespace whose defaults rely on a
# -default section silently loses it
is_deeply(
    pfconfig::namespaces::config::TLS->new($cache)->{import_params},
    { -default => 'tls-common' },
    "config::TLS carries its -default through import_params"
);

# Source-level guard: no config namespace may go back to building -import in
# init(). Cheaper and more complete than constructing all of them, several of
# which need a live cache.
{
    my @offenders;
    for my $file (glob "/usr/local/pf/lib/pfconfig/namespaces/config/*.pm") {
        open my $fh, '<', $file or next;
        my $src = do { local $/; <$fh> };
        close $fh;
        next unless $src =~ /\nsub init\b.*?\n}/s;
        my $init = $&;
        push @offenders, ($file =~ m{([^/]+)$})[0]
            if $init =~ /added_params.*?-import/s;
    }
    is_deeply(\@offenders, [],
        "no config namespace builds its -import inside init()");
}

=head2 AccessScopes must materialize the parent's import itself

AccessScopes::build calls $config->init and then builds its own pf::IniFiles from
$config->{added_params}. Now that the parent only declares import_file, build has
to call import_config or the filter engines silently come up with no defaults --
on a stock install that empties DNS_Scopes and VlanScopes outright.

=cut

use_ok("pfconfig::namespaces::FilterEngine::DNS_Scopes");
{
    my @captured;
    my $real_new = \&pf::IniFiles::new;
    {
        no warnings 'redefine';
        *pf::IniFiles::new = sub { push @captured, {@_[1 .. $#_]}; return $real_new->(@_) };
    }

    pfconfig::namespaces::FilterEngine::DNS_Scopes->new($cache)->build();

    {
        no warnings 'redefine';
        *pf::IniFiles::new = $real_new;
    }

    my ($main) = grep { ($_->{-allowempty} // 0) && $_->{-file} } @captured;
    ok($main, "AccessScopes built an IniFiles for the filter file");
    isa_ok($main->{-import}, "pf::IniFiles",
        "AccessScopes passed the parent's defaults as -import");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

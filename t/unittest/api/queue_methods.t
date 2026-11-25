#!/usr/bin/perl

=head1 NAME

queue_methods.t

=head1 DESCRIPTION

Every pf::api method sent to the queue must be allowed in the queue (tagged
Queue or AllowedAsAction), or the consumer refuses it and the work is dropped.

The source tree is scanned for the calls to notify, notify_all,
notify_delayed and notify_hashed made on a pf::api::queue or
pf::api::queue_cluster client, and for the methods the Go pfdetect parsers
submit to the queue. A method given by a variable can't be checked here: the
consumer still refuses it if it isn't allowed.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More;
use Test::NoWarnings;
use File::Find;
use pf::file_paths qw($install_dir);
use pf::api;

plan tests => 4;

# A client of the queue: built from pf::api::queue or pf::api::queue_cluster,
# or from $SEND_MAIL_API_CLIENT (pf::api::queue by default).
my $QUEUE_CLIENT_RE = qr/(?:\bpf::api::queue(?:_cluster)?|\$SEND_MAIL_API_CLIENT)->new\b/;
my $NOTIFY_RE = qr/->(notify(?:_all|_delayed|_hashed)?)\s*\(/;
# a quoted method name, or a bareword before a fat comma
my $METHOD_RE = qr/\G\s*(?:'(\w+)'|"(\w+)"|(\w+)\s*=>)/;
# notify_delayed and notify_hashed take the delay or the hash key first
my %SKIP_FIRST_ARG = (notify_delayed => 1, notify_hashed => 1);

my $PRUNE_RE = qr{/(?:node_modules|dist|lib_perl|var|logs|t|\.git)$};

my %queued;    # method => [ "file:line", ... ]

sub line_of {
    my ($content, $pos) = @_;
    return 1 + (substr($content, 0, $pos) =~ tr/\n//);
}

# true if the block the text starts in is closed within the text
sub block_closes {
    my ($text) = @_;
    my $depth = 0;
    for my $brace ($text =~ /([{}])/g) {
        $depth += $brace eq '{' ? 1 : -1;
        return 1 if $depth < 0;
    }
    return 0;
}

sub scan_perl {
    my ($path, $content) = @_;
    # subs returning a queue client, like api_client in pfdhcplistener
    my @factories = $content =~ /\bsub\s+(\w+)\s*\{[^{}]*?\breturn\s+$QUEUE_CLIENT_RE/g;
    my $client_re = @factories
        ? qr/$QUEUE_CLIENT_RE|\b(?:@{[join '|', @factories]})\s*\(/
        : $QUEUE_CLIENT_RE;

    while ($content =~ /$NOTIFY_RE/g) {
        my ($call, $start, $args_pos) = ($1, $-[0], $+[0]);
        my $before = substr($content, 0, $start);
        my $is_queue;
        if ($before =~ /\$(\w+)\s*\z/) {
            # $client->notify: the last assignment of $client before the call,
            # in the same sub. A "my $client" in a block closed before the call
            # is another variable.
            my $var = $1;
            my ($scope) = $before =~ /(?:.*\bsub\s+\w+)?(.*)\z/s;
            my $rhs;
            while ($scope =~ /(\bmy\s+)?\$\Q$var\E\s*=(?![=~>])([^;]*);/g) {
                my ($my, $value) = ($1, $2);
                next if $my && block_closes(substr($scope, $+[0]));
                $rhs = $value;
            }
            $is_queue = defined($rhs) && $rhs =~ $client_re;
        } elsif ($before =~ /\)\s*\z/) {
            # pf::api::queue->new(...)->notify: the statement builds the client
            my ($statement) = $before =~ /([^;]*)\z/;
            $is_queue = $statement =~ $client_re;
        }
        next unless $is_queue;

        pos($content) = $args_pos;
        if ($SKIP_FIRST_ARG{$call}) {
            next unless $content =~ /\G[^,;]*,/gc;
        }
        if ($content =~ /$METHOD_RE/gc) {
            my $method = $1 // $2 // $3;
            push @{$queued{$method}}, "$path:" . line_of($content, $start);
        }
        pos($content) = $args_pos;
    }
}

sub scan_go {
    my ($path, $content) = @_;
    while ($content =~ /\bPfqueueApiCall\s*\{\s*Method:\s*"(\w+)"/g) {
        push @{$queued{$1}}, "$path:" . line_of($content, $-[0]);
    }
}

find({
    no_chdir => 1,
    wanted => sub {
        my $path = $File::Find::name;
        if (-d $path) {
            $File::Find::prune = 1 if $path =~ $PRUNE_RE;
            return;
        }
        return if -l $path || !-f _;
        my $go = $path =~ m{/go/detectparser/[^/]+\.go$} && $path !~ /_test\.go$/;
        my $perl = $path =~ /\.p[ml]$/ || $path =~ m{/s?bin/[^/.]+$};
        return unless $go || $perl;
        open(my $fh, '<', $path) or return;
        local $/ = undef;
        my $content = <$fh>;
        close($fh);
        if ($go) {
            scan_go($path, $content);
        } elsif ($path =~ /\.p[ml]$/ || $content =~ /\A#!.*perl/) {
            scan_perl($path, $content);
        }
    },
}, map { "$install_dir/$_" } qw(lib html sbin bin go/detectparser));

# The scan must still find the queue producers it is meant to check.
my @expected = qw(
    process_dhcpv4 process_dhcpv6 fingerbank_process fingerbank_process_retry
    send_email cache_user_ntlm insert_user_in_redis_cache push_acls event_add
);
my @missing = grep { !$queued{$_} } @expected;
ok(!@missing, "the scan finds the known queue producers")
    or diag("not found: @missing");

# A method sent over JSON-RPC is not a queue method.
ok(!$queued{clear_portal_session}, "a method sent over JSON-RPC is not taken for a queue method");

my @refused = grep { !pf::api->isAllowedInQueue($_) } sort keys %queued;
ok(!@refused, "every method sent to the queue is allowed in the queue")
    or diag(join("\n", "Tag these pf::api methods with Queue (or AllowedAsAction):",
        map { "  $_: @{$queued{$_}}" } @refused));

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

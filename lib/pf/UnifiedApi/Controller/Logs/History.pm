package pf::UnifiedApi::Controller::Logs::History;

=head1 NAME

pf::UnifiedApi::Controller::Logs::History -

=cut

=head1 DESCRIPTION

Reads historical log content from /usr/local/pf/logs/ (active file plus
.log.<N>.gz rotations) and returns events filtered by time range and
optional regex/substring filter. Mirrors the cursor-based polling shape
of the SaaS eslogs/tail endpoint so the frontend code path stays unified.

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';

use IO::File;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Time::Piece;
use pf::constants::syslog;
use pf::file_paths qw($log_dir);
use pf::log;

use constant MAX_EVENTS => 500;

# 2026-06-01T02:36:06.330130+02:00 packetfence1 pfperl-api-docker-wrapper[78580]: rest of line
my $LINE_RE = qr/^
    (\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+\-]\d{2}:\d{2}|Z))   # timestamp
    \s+(\S+)                                                                # hostname
    \s+([^\[\s:]+)(?:\[\d+\])?:                                             # process (with optional [pid])
    \s+(.*)$
/x;

sub options {
    my ($self) = @_;
    my @files = sort {
        lc($a->{description}) cmp lc($b->{description})
    } @pf::constants::syslog::SyslogInfo;

    my @allowed = map {
        { text => $_->{description}, value => $_->{name} }
    } @files;

    return $self->render(json => {
        meta => {
            filter => {
                type => 'string', required => \0, default => undef, placeholder => undef,
            },
            filter_is_regexp => {
                type => 'string', required => \0, default => undef, placeholder => \0,
            },
            files => {
                type => 'array', required => \1, placeholder => undef, default => undef,
                item => {
                    type => 'string', required => \1, placeholder => undef, default => undef,
                    allowed => \@allowed,
                },
            },
            start => {
                type => 'string', required => \0, default => undef,
                placeholder => 'ISO-8601 timestamp (inclusive lower bound)',
            },
            end => {
                type => 'string', required => \0, default => undef,
                placeholder => 'ISO-8601 timestamp (exclusive upper bound)',
            },
        },
    });
}

sub query {
    my ($self) = @_;
    my $body   = $self->req->json // {};
    my $resp   = $self->_query($body);
    return $self->render(json => $resp->{json}, status => $resp->{status});
}

# Private helper that does the work and returns {json => ..., status => ...}.
# Extracted so pf::UnifiedApi::Controller::Logs::ClusterHistory can call it
# in-process on standalone installs without an HTTP hop.
sub _query {
    my ($self, $body) = @_;

    my $files = $body->{files} // [];
    return { status => 422, json => {
        message => "No files were specified",
        errors  => [], status => 422,
    } } unless ref($files) eq 'ARRAY' && @$files;

    my %allowed = map { $_->{name} => 1 } @pf::constants::syslog::SyslogInfo;
    my @bad = grep { !$allowed{$_} } @$files;
    return { status => 422, json => {
        message => "Unknown file(s): " . join(',', @bad),
        errors  => [], status => 422,
    } } if @bad;

    my $start_ms = _iso_to_ms($body->{start});
    my $end_ms   = _iso_to_ms($body->{end});
    my $cursor   = $body->{cursor} // {};
    my $filter   = $body->{filter};
    my $is_regex = $body->{filter_is_regexp} ? 1 : 0;

    my $matcher;
    if (defined $filter && length $filter) {
        if ($is_regex) {
            my $re = eval { qr/$filter/ };
            return { status => 422, json => {
                message => "Invalid regex filter: $@", errors => [], status => 422,
            } } if $@;
            $matcher = sub { $_[0] =~ $re };
        } else {
            my $lc = lc $filter;
            $matcher = sub { index(lc($_[0]), $lc) >= 0 };
        }
    }

    my @events;
    my %new_cursor = %$cursor;

    FILE: for my $name (@$files) {
        my $floor_ms = $cursor->{$name} // $start_ms;
        my @sources  = _enumerate_sources($name, $floor_ms, $end_ms);

        for my $src (@sources) {
            my $fh = _open_source($src);
            next unless $fh;
            while (my $line = <$fh>) {
                last FILE if @events >= MAX_EVENTS;
                chomp $line;
                next unless length $line;
                next if defined $matcher && !$matcher->($line);

                my $meta = _parse_line($line, $name);
                my $ts_ms = $meta->{timestamp_ms};
                next unless defined $ts_ms;
                next if defined $floor_ms && $ts_ms <= $floor_ms;
                next if defined $end_ms   && $ts_ms >= $end_ms;

                push @events, {
                    data => {
                        raw  => $line,
                        meta => {
                            timestamp          => $meta->{timestamp},
                            hostname           => $meta->{hostname},
                            process            => $meta->{process},
                            syslog_name        => $meta->{syslog_name},
                            log_level          => $meta->{log_level},
                            filename           => $name,
                            log_without_prefix => $meta->{log_without_prefix},
                        },
                    },
                };
                $new_cursor{$name} = $ts_ms;
            }
            close $fh;
        }
    }

    return { status => 200, json => {
        events => \@events,
        cursor => \%new_cursor,
    } };
}

# Return [ {path => ..., gz => 0|1, mtime => ...}, ... ] in chronological order
# (oldest first), filtered to those whose mtime intersects [floor_ms, end_ms].
sub _enumerate_sources {
    my ($name, $floor_ms, $end_ms) = @_;

    my $active = "$log_dir/$name";
    my @candidates;
    push @candidates, { path => $active, gz => 0 } if -f $active;

    if (opendir(my $dh, $log_dir)) {
        my @rotations;
        while (my $entry = readdir($dh)) {
            next unless $entry =~ /^\Q$name\E\.(\d+)\.gz$/;
            push @rotations, { path => "$log_dir/$entry", gz => 1, idx => $1 };
        }
        closedir $dh;
        # Higher index = older; read oldest first.
        @rotations = sort { $b->{idx} <=> $a->{idx} } @rotations;
        unshift @candidates, @rotations;
    }

    # logrotate runs daily, so a rotated file's mtime is approximately the
    # right edge of its content window and (mtime - 1 day) is the left edge.
    # Drop a rotation whose window cannot overlap [floor_ms, end_ms]. The
    # active file always passes — its content extends to "now".
    my $DAY_MS = 86_400_000;
    my @kept;
    for my $c (@candidates) {
        my $mtime = (stat($c->{path}))[9];
        next unless defined $mtime;
        my $mtime_ms = $mtime * 1000;
        if ($c->{gz}) {
            next if defined $floor_ms && $mtime_ms < $floor_ms;
            next if defined $end_ms   && ($mtime_ms - $DAY_MS) > $end_ms;
        }
        push @kept, { %$c, mtime => $mtime_ms };
    }
    return @kept;
}

sub _open_source {
    my ($src) = @_;
    if ($src->{gz}) {
        my $z = IO::Uncompress::Gunzip->new($src->{path}, MultiStream => 1, AutoClose => 1);
        unless ($z) {
            get_logger->warn("History: cannot open $src->{path}: $GunzipError");
            return;
        }
        return $z;
    }
    my $fh = IO::File->new($src->{path}, '<');
    unless ($fh) {
        get_logger->warn("History: cannot open $src->{path}: $!");
        return;
    }
    return $fh;
}

# Map log4perl + golang lvl + apache severity tokens to short labels.
my %LEVEL_MAP = (
    DEBUG => 'DEBUG', INFO  => 'INFO',  WARN  => 'WARN',
    ERROR => 'ERROR', FATAL => 'FATAL', TRACE => 'TRACE',
    dbug  => 'DEBUG', info  => 'INFO',  warn  => 'WARN',
    eror  => 'ERROR', crit  => 'FATAL',
);

sub _parse_line {
    my ($line, $filename) = @_;
    my %meta = (
        timestamp_ms       => undef,
        timestamp          => '',
        hostname           => '',
        process            => '',
        syslog_name        => '',
        log_level          => '',
        log_without_prefix => $line,
    );

    if ($line =~ $LINE_RE) {
        my ($ts, $host, $proc, $rest) = ($1, $2, $3, $4);
        $meta{timestamp}          = $ts;
        $meta{hostname}           = $host;
        $meta{process}            = $proc;
        $meta{syslog_name}        = $proc;
        $meta{log_without_prefix} = $rest;
        $meta{timestamp_ms}       = _iso_to_ms($ts);

        if ($rest =~ /\b(DEBUG|INFO|WARN|ERROR|FATAL|TRACE)\b/) {
            $meta{log_level} = $LEVEL_MAP{$1} // $1;
        } elsif ($rest =~ /\blvl=(dbug|info|warn|eror|crit)\b/) {
            $meta{log_level} = $LEVEL_MAP{$1};
        }
    }
    return \%meta;
}

sub _iso_to_ms {
    my ($s) = @_;
    return undef unless defined $s && length $s;
    # Normalise fractional seconds & timezone for Time::Piece.
    my ($base, $frac, $tz) = $s =~ /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?(.*)$/;
    return undef unless defined $base;
    $tz //= '';
    $tz = '+0000' if $tz eq 'Z' || $tz eq '';
    $tz =~ s/://;
    my $t = eval { Time::Piece->strptime("${base}${tz}", "%Y-%m-%dT%H:%M:%S%z") };
    return undef if $@ || !$t;
    my $ms = $t->epoch * 1000;
    if (defined $frac && length $frac > 1) {
        my $f = substr($frac, 1);
        $f = substr($f . "000", 0, 3);
        $ms += $f;
    }
    return $ms;
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

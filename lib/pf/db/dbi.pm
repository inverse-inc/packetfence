package pf::db::dbi;

=head1 NAME

pf::db::dbi - DBI handle subclass that prepends the ProxySQL routing remark

=cut

=head1 DESCRIPTION

Install it with the C<RootClass> connect attribute:

    DBI->connect($dsn, $user, $pass, { ..., RootClass => 'pf::db::dbi' });

Every C<prepare>, C<prepare_cached> and C<do> on such a handle prepends
C</* pf:E<lt>serviceE<gt>[:E<lt>unitE<gt>] */> to the statement, so ProxySQL
can route it by the service that issued it. The C<select*> helpers call
C<prepare> internally, so they are covered transitively.

This lives on its own, with no dependency on pf::config, so that the handles
created outside pf::db can use it too: pf::CHI::db (C<chi_cache>, read on
every RADIUS request by pf::SwitchFactory) and pfconfig::backend::mysql
(C<keyed>). Both are loaded by pf::db's own dependencies, so they cannot load
pf::db itself.

=cut

use strict;
use warnings;
use DBI;
use File::Basename qw(basename);
use Log::Log4perl;

our @ISA = ('DBI');

=head1 SUBROUTINES

=over

=item pf_query_comment

Build the ProxySQL routing remark for the current execution context.

Format: C</* pf:E<lt>serviceE<gt>[:E<lt>unitE<gt>] */>

C<service> is the running daemon (the logging 'proc' MDC, which defaults to
basename($0)). C<unit> is the logical work unit (a pfcron job id or pfqueue task
type) when one has been stamped in the 'pf_unit' MDC at a dispatch point;
otherwise it is omitted and C<service> is the whole routing bucket.

ProxySQL rules should match this with C<match_pattern> (not C<match_digest>,
which strips comments) anchored on C<^/\* pf:>. Note the tag may contain C<.>,
C</> and C<->; escape these (or use character classes) when matching a specific
service/unit, since C<match_pattern> is a regex.

=cut

sub pf_query_comment {
    my $service = Log::Log4perl::MDC->get('proc');
    $service = basename($0) unless defined $service && length $service;
    my $tag = 'pf:' . sanitize_query_tag($service);
    my $unit = Log::Log4perl::MDC->get('pf_unit');
    if (defined $unit && length $unit) {
        my $u = sanitize_query_tag($unit);
        $tag .= ":$u" if length $u;
    }
    return "/* $tag */";
}

=item sanitize_query_tag

Make a value safe to embed inside a SQL comment: never allow the comment
terminator, normalize package separators, and keep only routing-safe characters.

=cut

sub sanitize_query_tag {
    my ($v) = @_;
    return '' unless defined $v;
    $v =~ s{\*/}{}g;            # never allow the comment terminator
    $v =~ s/::/\//g;            # perl package separator -> slash
    $v =~ s/\s+/_/g;            # collapse whitespace
    $v =~ s{[^A-Za-z0-9_\-/.]}{}g;
    return $v;
}

=item decorate_statement

Return a copy of the SQL statement with the routing remark prepended, unless it
is already decorated. Works on a copy (never the caller's value), so it is safe
for static string literals -- unlike modifying DBI's @_ alias in place, which
dies on read-only literals. The decorated SQL is what gets prepared, so it also
becomes the prepare_cached cache key (distinct units => distinct cached
statements).

=cut

sub decorate_statement {
    my ($sql) = @_;
    return $sql unless defined $sql;
    return $sql if $sql =~ m{^\s*/\* pf:};
    return pf_query_comment() . ' ' . $sql;
}

=back

=cut

{
    package pf::db::dbi::st;
    our @ISA = ('DBI::st');

    package pf::db::dbi::db;
    our @ISA = ('DBI::db');

    sub prepare {
        my ($dbh, $statement, @attr) = @_;
        return $dbh->SUPER::prepare(pf::db::dbi::decorate_statement($statement), @attr);
    }

    sub prepare_cached {
        my ($dbh, $statement, @attr) = @_;
        return $dbh->SUPER::prepare_cached(pf::db::dbi::decorate_statement($statement), @attr);
    }

    sub do {
        my ($dbh, $statement, @attr) = @_;
        return $dbh->SUPER::do(pf::db::dbi::decorate_statement($statement), @attr);
    }
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

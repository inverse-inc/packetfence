#!/usr/bin/perl

=head1 NAME

radius_rest_format_response

=head1 DESCRIPTION

pf::radius::rest::format_response maps the pf::radius return code to the HTTP
status rlm_rest sees: policy decisions stay 401 ("reject"), infrastructure
failures become 503 ("fail") so the radiusd post-auth policy can leave the
request unanswered instead of tearing the session down with an Access-Reject.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 15;
use pf::radius::constants;

use_ok('pf::radius::rest');

# Returns undef when format_response succeeds, the HTTP status of the
# pf::api::error it died with otherwise.
sub status_of {
    my ($ret) = @_;
    my $ok = eval { pf::radius::rest::format_response($ret); 1 };
    return undef if $ok;
    my $e = $@;
    return ref($e) eq 'pf::api::error' ? $e->status : "unexpected: $e";
}

# Success codes pass through, flagged allow, with the audit stash mapped to control:
my $r = pf::radius::rest::format_response([
    $RADIUS::RLM_MODULE_OK,
    'Reply-Message' => 'welcome',
    RADIUS_AUDIT    => { 'PacketFence-Role' => 'employee' },
]);
is($r->{'control:PacketFence-Authorization-Status'}, 'allow', 'OK is allowed');
is($r->{'Reply-Message'}, 'welcome', 'reply attributes preserved');
is($r->{'control:PacketFence-Role'}, 'employee', 'RADIUS_AUDIT mapped to control attributes');
ok(!exists $r->{RADIUS_AUDIT}, 'RADIUS_AUDIT pseudo attribute removed');

is(status_of([$RADIUS::RLM_MODULE_NOOP]), undef, 'NOOP does not die');
is(status_of([$RADIUS::RLM_MODULE_UPDATED]), undef, 'UPDATED does not die');

# USERLOCK is a deliberate deny carried inside a 200 so radiusd can audit it.
$r = pf::radius::rest::format_response([$RADIUS::RLM_MODULE_USERLOCK]);
is($r->{'control:PacketFence-Authorization-Status'}, 'deny', 'USERLOCK is a deny');

# Policy decisions: 401 -> rlm_rest "reject" -> Access-Reject.
is(status_of([$RADIUS::RLM_MODULE_REJECT]), 401, 'REJECT answers 401');
is(status_of([$RADIUS::RLM_MODULE_FAIL, 'Reply-Message' => 'Switch is not managed by PacketFence']),
    401, 'a FAIL without failure marker is still a deny (401)');

# Infrastructure failures: 503 -> rlm_rest "fail" -> radiusd policy decides.
is(status_of([$RADIUS::RLM_MODULE_FAIL, 'Reply-Message' => 'Database is unavailable', RADIUS_FAILURE => 'database']),
    503, 'FAIL flagged RADIUS_FAILURE answers 503');
is(status_of(undef), 503, 'undef result (handler died) answers 503');
is(status_of([]), 503, 'empty result answers 503');
is(status_of([undef]), 503, 'undefined return code answers 503');

# The marker never leaks into the response body.
my $ok = eval {
    pf::radius::rest::format_response([$RADIUS::RLM_MODULE_FAIL, RADIUS_FAILURE => 'database']);
    1;
};
ok(!$ok && ref($@) eq 'pf::api::error' && !exists $@->response->{RADIUS_FAILURE},
    'RADIUS_FAILURE pseudo attribute removed from the error response');

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

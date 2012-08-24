package pf::soh;

=head1 NAME

pf::soh - A module to evaluate and respond to SoH requests

=head1 SYNOPSIS

This module contains the infrastructure necessary to evaluate
statement-of-health (SoH) requests tunnelled inside 802.1x/EAP
authentication negotiations.

FreeRADIUS passes SoH requests through a separate virtual server, which
uses a perl module to forward the requests via SOAP to pf::WebAPI, which
instantiates a pf::soh object to generate a suitable response.

The methods in pf::soh can be overriden in pf::soh::custom.

=cut

use strict;
use warnings;

use Log::Log4perl;
use Data::Dumper;
use Try::Tiny;

use pf::config;
use pf::db;
use pf::radius::constants;
use pf::violation;
use pf::util;

our $VERSION = 1.00;

# Scaffolding required to use pf::db

our $soh_db_prepared = 0;
our $soh_statements = {};

sub soh_db_prepare {
    # Fetch any filters that have one or more conditions and tell us to
    # do something when those conditions match.

    $soh_statements->{'soh_filters'} = get_db_handle()->prepare(<<"    SQL");
        select filter_id, name, action, vid
            from soh_filters s
            where ((action = 'violation' and vid is not null) or
                (action is not null and action <> 'violation')) and
                (select count(*) from soh_filter_rules where
                 filter_id=s.filter_id) >= 1
            order by filter_id asc
    SQL

    # We could try to be more selective about which rules to fetch, but
    # it isn't worth the bother until proven otherwise.

    $soh_statements->{'soh_rules'} = get_db_handle()->prepare(<<"    SQL");
        select filter_id, class, op, status from soh_filter_rules
            order by rule_id asc
    SQL

    $soh_statements->{'soh_filter'} = get_db_handle()->prepare(<<"    SQL");
        SELECT filter_id, name, action, vid
            FROM soh_filters
            WHERE filter_id = ?
    SQL

    $soh_statements->{'soh_filter_rules'} = get_db_handle()->prepare(<<"    SQL");
        SELECT rule_id, class, op, status
            FROM soh_filter_rules
            WHERE filter_id = ?
    SQL

    $soh_statements->{'soh_filter_add'} = get_db_handle()->prepare(<<"    SQL");
        INSERT INTO soh_filters (
            name, action, vid
        ) VALUES (
            ?, ?, ?
        )
    SQL

    $soh_statements->{'soh_filter_update'} = get_db_handle()->prepare(<<"    SQL");
        UPDATE soh_filters SET
            action = ?, vid = ?
        WHERE filter_id = ?
    SQL

    $soh_statements->{'soh_filter_delete'} = get_db_handle()->prepare(<<"    SQL");
        DELETE FROM soh_filters
        WHERE filter_id = ?
    SQL

    $soh_statements->{'soh_filter_rule_add'} = get_db_handle()->prepare(<<"    SQL");
        INSERT INTO soh_filter_rules (
            filter_id, class, op, status
        ) VALUES (
            ?, ?, ?, ?
        )
    SQL

    $soh_statements->{'soh_filter_rules_delete'} = get_db_handle()->prepare(<<"    SQL");
        DELETE FROM soh_filter_rules
        WHERE filter_id = ?
    SQL

}

=head1 SUBROUTINES

=over

=item * new - returns a new pf::soh object

=cut

sub new {
    my ($class) = @_;

    my $self = {
        logger => Log::Log4perl->get_logger("soh")
    };

    return bless $self, $class;
}

=item * authorize - handles the SoH request

Takes a RADIUS request containing synthetic SoH attributes, forwarded
through the SoH virtual server, decides how to handle it based on the
filters created by the user, and returns a suitable response. This is
the top-level function, which does very little work itself.

=cut

sub authorize {
    my $self = shift;
    my ($rq) = @_;

    unless ($self->parse_request($rq)) {
        return [$RADIUS::RLM_MODULE_FAIL];
    }

    # If the client doesn't support SoH, we bail out early. (Can this
    # ever happen? We're being forwarded a request from the soh-server,
    # after all.) But perhaps one should be able to filter on this too?
    unless ($self->{request}->{"SoH-Supported"} eq 'yes') {
        return $RADIUS::RLM_MODULE_NOOP;
    }

    $self->{logger}->info("Evaluating SoH from $self->{client_description}");

    return [ $self->evaluate($self->filters()) ];
}

=item * parse_request - parses a request

This function takes a hashref containing RADIUS value pairs, parses
them, and sets helpful new values in the same hash.

=cut

sub parse_request {
    my $self = shift;
    my ($rq) = @_;

    my $result;
    try {
        $self->{request} = $rq;

        # Do we know who the client is?
        my $mac;
        unless ($mac = $rq->{"Calling-Station-Id"}) {
            die "No Calling-Station-Id specified";
        }
        unless (defined ($self->{mac_address} = clean_mac($mac))) {
            die "Couldn't parse Calling-Station-Id $mac";
        }

        # Build up a client description
        my $client = "";
        $client .= ($rq->{"SoH-MS-Machine-Role"} || "client");
        $client .= " ";
        $client .= ($rq->{"SoH-MS-Machine-Name"} || "(name unknown)");

        my @extra;
        push @extra, "MAC: $mac";
        if (my $port = $rq->{"NAS-Port"}) {
            push @extra, "Port: $port";
        }
        if (my $user = $rq->{"User-Name"}) {
            push @extra, "User: $user";
        }
        push @extra, "OS: " . $self->_identify_os($rq);

        my $id;
        unless ($id = $rq->{"SoH-MS-Correlation-Id"}) {
            die "No correlation id specified";
        }
        push @extra, "id: $id";

        $client .= " (". join("; ", @extra) .")";

        $self->{client_description} = $client;

        # Parse the actual health status
        my $status = $rq->{"SoH-MS-Windows-Health-Status"};
        unless (ref $status eq 'ARRAY' && @$status) {
            die "SoH-MS-Windows-Health-Status didn't contain a health status";
        }

        # Each line looks like: class status [word|attr=val]...
        my %ok;
        foreach my $line (@$status) {
            my ($class, $status, @attrs) = split / /, $line;

            if ($line =~ /^[0-9]* unknown /) {
                $self->{logger}->warn(
                    "Received unknown SoH-MS-Windows-Health-Status line: '$line'"
                );
                next;
            }

            # The health class and status should be one of the following
            # values (see healthclass2str). We accept other values with
            # a warning, though.

            my %classes = map {$_ => 1}
                qw(security-updates auto-updates firewall antispyware antivirus);
            my %statuses = map {$_ => 1} qw(ok warn error);

            unless (exists $classes{$class}) {
                $self->{logger}->warn("Unrecognised health class: $class");
            }

            unless (exists $statuses{$status}) {
                $self->{logger}->warn("Unrecognised status: $status");
            }

            # The remainder of the line consists of words (e.g. "all-installed")
            # or "attr=val" clauses (e.g. "action=install"), or numeric values
            # for things FreeRADIUS does not recognise.
            #
            # (The expected attributes are generated in src/main/soh.c)

            my %attrs;
            foreach (@attrs) {
                my ($a, $v) = split /=/;
                $attrs{$a} = defined $v ? $v : 1;
            }

            # Add to an array of parsed lines for each class.

            push @{$ok{$class}}, {
                status => $status, %attrs
            };
        }

        unless (%ok) {
            die "Couldn't parse any SoH-MS-Windows-Health-Status lines";
        }

        $self->{status} = \%ok;
        $result = $TRUE;
    }
    catch {
        chomp;
        $self->{logger}->error($_);
        $result = $FALSE;
    };

    return $result;
}

=item * evaluate - evaluates an SoH request against filters

This method takes an SoH request and an array of filters to match
against, evaluates the request against each filter in turn, until
one matches, and does whatever that filter specifies. It returns
the $RADIUS::RLM_MODULE_* code to be sent back to FreeRADIUS.

=cut

sub evaluate {
    my $self = shift;
    my ($filters) = @_;

    my $code = $RADIUS::RLM_MODULE_NOOP;
    my %actions = (
        accept => $RADIUS::RLM_MODULE_OK,
        reject => $RADIUS::RLM_MODULE_FAIL,
        violation => $RADIUS::RLM_MODULE_OK
    );

    # Check if each filter's rules match, and keep going until there are
    # no more filters, or a filter returns reject.

    foreach my $filter (@$filters) {
        my $matched = 0;
        my $rules = $filter->{rules};
        foreach my $rule (@$rules) {
            if ($self->matches($rule)) {
                $matched++;
            }
        }
        if (@$rules) {
            my $hit = $matched == @$rules;
            my $action = $filter->{action};

            if ($action eq 'violation') {
                if ($hit) {
                    $self->trigger_violation($filter);
                }
            }

            if ($hit) {
                $self->{logger}->info(
                    "MAC $self->{mac_address} matched filter $filter->{name}"
                );
                $code = $actions{$action};
                last if $action eq 'reject';
            }
        }
    }

    return $code;
}

=item * matches - does a request match a given rule?

Returns true if the specified condition is met by the request, and false
otherwise. We could (always) be more clever about how we match. The UI to
define matches is simple, but the matching process can be as complex as it
needs to be.

The question we answer is: "does any status line match this rule?"

=cut

sub matches {
    my $self = shift;

    my ($rule) = @_;
    my $stmts = $self->{status}{$rule->{class}} || [];

    foreach my $stmt (@{$stmts}) {
        return 1 if $self->matches_one($rule, $stmt);
    }

    return 0;
}

=item * matches_one - does a single status line match a given rule?

For every rule referring to a particular health class, this function is
called once for each corresponding status line, and returns true if the
rule matches, and false otherwise.

=cut

sub matches_one {
    my $self = shift;

    my ($rule, $stmt) = @_;
    my ($class, $op, $status) = @{$rule}{qw/class op status/};

    # Translate the status string into a set of words to match.
    # For example, "ok,enabled,!microsoft,snoozed" are split up,
    # matched separately, and the results ANDed together. But the
    # usual input will be a single word (and that's all the UI can
    # generate at the moment).

    my @words;
    foreach my $w (split /\s*,\s*/, $status) {
        if ($w eq 'disabled') {
            $w = '!enabled';
        }
        push @words, $w;
    }

    my $match;

    foreach my $w (@words) {
        my $m = 0;

        my $not = 0;
        if ($w =~ s/^!//) {
            $not = 1;
        }

        my %top = map { $_ => 1 } qw/ok warn error/;
        if ((exists $top{$w} && $stmt->{status} eq $w) || $stmt->{$w}) {
            $m = 1;
        }

        $m = (1, 0)[$m] if $not;

        unless (defined $match) {
            $match = $m;
            next;
        }

        $match = $match && $m;
    }

    $match = (1, 0)[$match] if $op eq 'isnot';

    my $yesno = (qw(No Yes))[$match];
    my $desc = join " ", $class, $stmt->{status},
        map { "$_=$stmt->{$_}" } grep { $_ ne 'status' }
            keys %$stmt;

    $self->{logger}->debug("Does ($desc) match ($class $op $status)? $yesno");

    return $match;
}

=item * trigger_violation - trigger a violation

Triggers a violation for the specified MAC address and filter.

=cut

sub trigger_violation {
    my $self = shift;
    my ($filter) = @_;

    $self->{logger}->debug(
        "Triggering violation $filter->{vid} for MAC $self->{mac_address} ".
        "and filter $filter->{name}"
    );
    pf::violation::violation_trigger(
        $self->{mac_address}, $filter->{filter_id}, "soh"
    );
}

=item * filter - fetch a filter from the db

Returns a hashref representing a single SoH filter.

=cut

sub filter {
    my ($self, $filter_id) = @_;

    my (@results, $filter_ref);

    @results = db_data("soh", $soh_statements, "soh_filter", $filter_id);
    $filter_ref = pop @results;
    if ($filter_ref) {
        @results = db_data("soh", $soh_statements, "soh_filter_rules", $filter_id);
        $filter_ref->{rules} = \@results;
    }

    return $filter_ref;
}

=item * filters - fetch filters from the db

Returns a reference to an array of hashrefs, each representing a single
SoH filter.

=cut

sub filters {
    my $self = shift;

    # Fetch filters and rules separately, then merge.
    my @filters = db_data("soh", $soh_statements, "soh_filters");
    my @rules = db_data("soh", $soh_statements, "soh_rules");

    foreach my $filter (@filters) {
        $filter->{rules} = [
            grep $_->{filter_id} == $filter->{filter_id}, @rules
        ];
    }

    return [ @filters ];
}

=item * create_filter

=cut

sub create_filter {
    my ($self, $name, $action, $vid) = @_;

    db_query_execute("soh", $soh_statements, 'soh_filter_add',
                     $name, $action, $vid
                    ) || return (0);
    my $id = get_db_handle()->last_insert_id((undef)x4);

    $self->{logger}->debug("Created filter $name (id $id)");

    return $id;
}

=item * update_filter

=cut

sub update_filter {
    my ($self, $filter_id, $action, $vid) = @_;

    db_query_execute("soh", $soh_statements, 'soh_filter_update',
                     $action, $vid, $filter_id
                    ) || return (0);

    return (1);
}

=item * delete_filter

=cut

sub delete_filter {
    my ($self, $filter_id) = @_;

    db_query_execute("soh", $soh_statements, 'soh_filter_delete',
                     $filter_id
                    ) || return (0);

    $self->{logger}->debug("Deleted filter " . $filter_id);

    return (1);
}

=item * create_rule

=cut

sub create_rule {
    my ($self, $filter_id, $class, $op, $status) = @_;

    db_query_execute("soh", $soh_statements, 'soh_filter_rule_add',
                     $filter_id, $class, $op, $status
                    ) || return (0);

    $self->{logger}->debug("Created rule $class/$op/$status for filter $filter_id");

    return (1);
}

=item * delete_rules

=cut

sub delete_rules {
    my ($self, $filter_id) = @_;

    db_query_execute("soh", $soh_statements, 'soh_filter_rules_delete',
                     $filter_id
                    ) || return (0);

    $self->{logger}->debug("Deleted rules of filter $filter_id");

    return (1);
}

=back

=cut

# Utility functions

sub _identify_os {
    my ($self, $rq) = @_;

    my $vendor = $rq->{"SoH-MS-Machine-OS-vendor"};
    my $major = $rq->{"SoH-MS-Machine-OS-version"};
    my $minor = $rq->{"SoH-MS-Machine-OS-release"};

    die "No operating system vendor specified" unless $vendor;
    die "No operating system version specified" unless $major;

    my $os;
    unless ($vendor eq 'Microsoft') {
        $os = $vendor;
        $os .= " $major";
        $os .= ".$minor" if defined $minor;
    }
    else {
        $os = "Microsoft Windows ";

        if ($major == 4 && $minor == 0) {
            $os .= "NT4";
        }
        elsif ($major == 5 && $minor == 0) {
            $os .= "2000";
        }
        elsif ($major == 5 && $minor == 1) {
            $os .= "XP";
        }
        elsif ($major == 5 && $minor == 2) {
            $os .= "Server 2003 (or 2003 R2)";
        }
        elsif ($major == 6 && $minor == 0) {
            $os .= "Vista (or Server 2008)";
        }
        elsif ($major == 6 && $minor == 1) {
            $os .= "7 (or Server 2008 R2)";
        }
        else {
            $os .= "${major}.$minor";
        }

        if (my $sp1 = $rq->{"SoH-MS-Machine-SP-version"}) {
            $os .= ", sp $sp1";
            if (my $sp2 = $rq->{"SoH-MS-Machine-SP-release"}) {
                $os .= ".$sp2";
            }
        }
    }

    return $os;
}

=head1 AUTHOR

Abhijit Menon-Sen <amenonsen@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

=cut

1;

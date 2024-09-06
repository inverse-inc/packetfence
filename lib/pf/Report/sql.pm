package pf::Report::sql;

=head1 NAME

pf::Report::sql -

=head1 DESCRIPTION

pf::Report::sql

=cut

use strict;
use warnings;
use Moose;
use pf::Report;
use pf::error qw(is_error);
use pf::util;
use Clone qw(clone);
use List::MoreUtils qw(any);
extends qw(pf::Report);

our %mapping = (
    cursor => 1,
    start_date => 1,
    end_date => 1,
);

has cursor_type => ( is => 'rw', isa => 'Str');

has cursor_field => ( is => 'rw', isa => 'Str|ArrayRef[Str]');

has cursor_default => ( is => 'rw', isa => 'Str|ArrayRef[Str]');

has has_limit => ( is => 'rw', isa => 'Str', default => 'enabled');

has has_date_range => ( is => 'rw', isa => 'Str', default => 'disabled');

has bindings => (is => 'rw', isa => 'ArrayRef[Str]');

has sql => ( is => 'rw', isa => 'Str');

sub generate_sql_query {
    my ($self, %info) = @_;
    my $sql = $self->sql;
    return ($sql, $self->create_bind(\%info));
}

sub is_cursor_field {
    my ($self, $field) = @_;
    my $f = $self->cursor_field;
    return 0 if !defined $f;
    if (!ref $f) {
        $f = [$f];
    }

    return any { $_ eq $field } @{$f};
}

sub options_has_date_range {
    my ($self) = @_;
    if (isenabled($self->has_date_range)) {
        return $pf::Report::JSON_TRUE;
    }

    return $pf::Report::JSON_FALSE;
}

sub create_bind {
    my ($self, $infos) = @_;
    my @bind;
    for my $b (@{$self->bindings}) {

        if ($b eq 'limit') {
            push @bind, $infos->{sql_limit};
            next;
        }

        if ($b =~ /^cursor\.(\d+)/) {
            push @bind, $infos->{cursor}[$1];
            next;
        }

        if (exists $mapping{$b}) {
            push @bind, $infos->{$b};
            next;
        }

    }

    return \@bind;
}

sub nextCursor {
    my ($self, $result, %infos) = @_;
    my $sql_limit = $infos{sql_limit};
    my $last_item;
    if (@$result == $sql_limit) {
        $last_item = pop @$result;
    }

    if ($last_item) {
        if ($self->cursor_type eq 'field') {
            return $last_item->{$self->cursor_field};
        }

        if ($self->cursor_type eq 'multi_field') {
            return [@{$last_item}{@{$self->cursor_field}}];
        }

        return $infos{cursor} + $infos{limit};
    }

    return undef;
}

sub validate_input {
    my ($self, $data) = @_;
    my @errors;

    $self->validate_required_field($data, \@errors);
    if (@errors) {
        return (422, { message => 'invalid request', errors => \@errors });
    }

    return (200, undef);
}

sub validate_required_field {
    my ($self, $data, $errors) = @_;
    if (isenabled($self->has_date_range)) {
        my $start_date = $data->{start_date};
        my $end_date = $data->{end_date};
        if (!$start_date) {
            push @$errors, { field => 'start_date', message => "must have a value" },
        }

        if (!$end_date) {
            push @$errors, { field => 'end_date', message => "must have a value" },
        }
    }

    return;
}

sub build_query_options {
    my ($self, $data) = @_;
    my ($status, $error) = $self->validate_input($data);
    if (is_error($status)) {
        return (422, $error);
    }
    my %options;
    $options{limit} = $data->{limit} // $self->default_limit // 25;
    $options{sql_limit} = $options{limit} + 1;
    if ($self->cursor_type eq 'offset') {
        $data->{cursor} = $options{offset} = $data->{cursor} // 0;
    } else {
        $options{cursor} = $data->{cursor} // clone($self->cursor_default);
    }

    for my $f (qw(start_date end_date)) {
        if (exists $data->{$f}) {
            my $v = $data->{$f};
            if (defined $v) {
                $options{$f} = $v;
            }
        }
    }

    return (200, \%options);
}

sub options_has_cursor {
    my ($self) = @_;
    return $self->cursor_type eq 'none' ? $pf::Report::JSON_FALSE : $pf::Report::JSON_TRUE;
}

sub options_has_limit {
    my ($self) = @_;
    return isenabled($self->has_limit) ? $pf::Report::JSON_TRUE : $pf::Report::JSON_FALSE;
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

1;

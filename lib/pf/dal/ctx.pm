package pf::dal::ctx;

=head1 NAME

pf::dal::ctx -

=head1 DESCRIPTION

pf::dal::ctx

=cut

use strict;
use warnings;
use pf::error qw(is_error);
use pf::dal::ctx::upsert;
use pf::dal::ctx::update;
our $GLOBAL = __PACKAGE__->new;

sub new {
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    return bless({DAL_ACTIONS => [], CACHED_OBJECTS => {}}, $class);
}

sub begin {
    my ($self) = @_;
    $self->_clear;
    return;
}

sub _clear {
    my ($self) = @_;
    @{$self->{DAL_ACTIONS}} = ();
    $self->{CACHED_OBJECTS} = {};
}

sub add {
    my ($self, @actions) = @_;
    for my $action (@actions) {
        if ($action->cacheable) {
            my $dal = $action->dal;
            next if ($self->in_cache($dal, $dal));
            $self->add_to_cache($dal);
        }
        push @{$self->{DAL_ACTIONS}}, @actions;
    }
}

sub in_cache {
    my ($self, $dal, $lookup) = @_;
    my $cache = $self->{CACHED_OBJECTS};
    my $dal_class = ref($dal) || $dal;
    my $dal_sub_key = join(':', map {$lookup->{$_}} @{$dal->primary_keys});
    return exists $cache->{$dal_class}{$dal_sub_key};
}

sub add_to_cache {
    my ($self, $dal) = @_;
    my $cache = $self->{CACHED_OBJECTS};
    my $dal_class = ref($dal) || $dal;
    my $dal_sub_key = join(':', map {$dal->{$_}} @{$dal->primary_keys});
    $cache->{$dal_class}{$dal_sub_key} = $dal;
    return;
}

sub get_from_cache {
    my ($self, $dal, $lookup) = @_;
    my $cache = $self->{CACHED_OBJECTS};
    my $dal_class = ref($dal) || $dal;
    my $dal_sub_key = join(':', map {$lookup->{$_}} @{$dal->primary_keys});
    if (!exists $cache->{$dal_class}{$dal_sub_key}) {
        return undef;
    }

    return $cache->{$dal_class}{$dal_sub_key};
}

sub flush {
    my ($self) = @_;
    my $actions = $self->{DAL_ACTIONS};
    if (@$actions == 0) {
        return;
    }

    my @statements;
    my @binds;
    my @used_actions;
    for my $action (@$actions) {
        my ($status, $sql, @bind) = $action->sql_bind;
        if (is_error($status)) {
            next;
        }

        next if ($status == $STATUS::NO_CONTENT);
        $sql =~ s/;\s*$//;
        push @statements, $sql;
        push @binds, @bind;
        push @used_actions, $action;
    }

    if (@statements == 0) {
        return;
    }

    my $sql = join(';', @statements) . ';';
    my ($status, $sth) = pf::dal->db_execute($sql, @binds);
    for my $action (@used_actions) {
        $action->process($status, $sth);
    }

    $sth->finish;
    $self->_clear;
    return;
}

sub find {
    my ($self, $dal, $lookup) = @_;
    my $obj = $self->get_from_cache($dal, $lookup);
    if (defined $obj) {
        return $obj;
    }

    (my $status, $obj) = $dal->find_or_new($lookup);
    if (is_error($status)) {
        return undef;
    }

    $self->add(pf::dal::ctx::upsert->new({dal => $obj}));
    return $obj;
}

sub add_update {
    my ($self, $dal, @args) = @_;
    $self->add(
        pf::dal::ctx::update->new({
            dal => $dal,
            args => [@args],
        })
    );
}

sub add_global {
    $GLOBAL->add(@_);
}

sub add_update_global {
    $GLOBAL->add_update(@_);
}

sub find_global {
    $GLOBAL->find(@_);
}

sub flush_global {
    $GLOBAL->flush;
}

sub begin_global {
    $GLOBAL->begin;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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

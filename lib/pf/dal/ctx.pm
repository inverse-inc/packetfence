package pf::dal::ctx;

=head1 NAME

pf::dal::ctx -

=head1 DESCRIPTION

pf::dal::ctx

=cut

use strict;
use warnings;
use pf::error qw(is_error);
our $GLOBAL = __PACKAGE__->new;

my @DAL_OBJS;

sub new {
    my ($proto) = @_;
    my $class = ref($proto) || $proto;
    return bless({}, $class);
}

sub begin {
    my ($self) = @_;
    $self->_clear;
    return;
}

sub _clear {
    my ($self) = @_;
    @{$self->{DAL_OBJS}} = ();
}

sub add {
    my ($self, @dals) = @_;
    push @{$self->{DAL_OBJS}}, @dals;
}

sub flush {
    my ($self) = @_;
    my $dals = $self->{DAL_OBJS};
    if (@$dals == 0) {
        return;
    }

    my @statements;
    my @binds;
    my @used_dals;
    for my $dal (@$dals) {
        my ($status, $sql, @bind) = $dal->save_sql_bind;
        if (is_error($status)) {
            next;
        }

        next if ($status == $STATUS::NO_CONTENT);
        $sql =~ s/;\s*$//;
        push @statements, $sql;
        push @binds, @bind;
        push @used_dals, @used_dals;
    }

    if (@statements == 0) {
        return;
    }

    my $sql = join(';', @statements) . ';';
    my ($status, $sth) = pf::dal->db_execute($sql, @binds);
    for my $dal (@used_dals) {
        $dal->post_save($status, $sth);
    }

    $sth->finish;
    $self->_clear;
    return;
}

sub find {
    my ($self, $dal, $lookup) = @_;
    my ($status, $obj) = $dal->find_or_new($lookup);
    if (is_error($status)) {
        return undef;
    }

    $self->add($obj);
    return $obj;
}

sub add_global {
    $GLOBAL->add(@_);
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

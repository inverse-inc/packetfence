package pf::SQL::Abstract;

=head1 NAME

pf::SQL::Abstract - PacketFence SQL::Abstract

=cut

=head1 DESCRIPTION

pf::SQL::Abstract

=cut

use strict;
use warnings;
BEGIN {
    $ENV{SQL_ABSTRACT_MORE_EXTENDS} = 'Classic';
    use SQL::Abstract::Classic;
    use SQL::Abstract::Plugin::InsertMulti;
}

use parent qw(SQL::Abstract::More);
use MRO::Compat;
use mro 'c3'; # implements next::method

use Params::Validate  qw/validate SCALAR SCALARREF CODEREF ARRAYREF HASHREF
                                  UNDEF  BOOLEAN/;
use Scalar::Util      qw/blessed reftype/;
use Carp;                                  

BEGIN {
    *puke = \&SQL::Abstract::puke;
    *belch = \&SQL::Abstract::belch;
    *_called_with_named_args = \&SQL::Abstract::More::_called_with_named_args;
}

{
    no strict 'refs';
    for my $f (qw(insert_multi update_multi _insert_multi _insert_multi_HASHREF _insert_multi_ARRAYREF _insert_multi_values _insert_multi_process_args)) {
        *{$f} = \&{"SQL::Abstract::Plugin::InsertMulti::$f"};
    }
}

#----------------------------------------------------------------------
# utility function : cheap version of Scalar::Does (too heavy to be included)
#----------------------------------------------------------------------
my %meth_for = (
  ARRAY => '@{}',
  HASH  => '%{}',
 );

sub does ($$) {
  my ($data, $type) = @_;
  my $reft = reftype $data;
  return defined $reft && $reft eq $type
      || blessed $data && overload::Method($data, $meth_for{$type});
}

use namespace::clean;

my %params_for_upsert = (
  -into         => {type => SCALAR},
  -values       => {type => SCALAR|ARRAYREF|HASHREF},
  -on_conflict  => {type => HASHREF, optional => 1},
);

my %params_for_update = (
  -table        => {type => SCALAR|SCALARREF|ARRAYREF},
  -set          => {type => HASHREF},
  -where        => {type => SCALAR|ARRAYREF|HASHREF, optional => 1},
  -order_by     => {type => SCALAR|ARRAYREF|HASHREF, optional => 1},
  -limit        => {type => SCALAR,                  optional => 1},
);

=head2 upsert

Creates an mysql INSERT with an optional ON DUPLICATE KEY UPDATE parameters.
It will create the ON DUPLICATE KEY UPDATE parameters if the hashref -on_conflict is passed as a parameter
The -on_conflict option uses the same format of the update -set parameter

   my ($sql, @bind) = $sql->upsert(-into => t, -values => {id => 1, f => "bob"}, -on_conflict => { f=> "bob" } );
   
   print "sql : '$sql', params(", join(", ", @bind),")\n";

Outputs:

  sql : 'INSERT INTO t (id, f) VALUES (?, ?) ON DUPLICATE KEY UPDATE f = ?', params (1, bob, bob)


=cut

sub upsert {
  my $self = shift;

  my @old_args;
  my $on_conflict;
  if (&_called_with_named_args) {
    # extract named args and translate to old SQLA API
    my %args = validate(@_, \%params_for_upsert);
    $on_conflict = delete $args{-on_conflict};
    @old_args = %args;
  }
  else {
    @old_args = @_;
  }
  # Create a regular insert
  my ($sql, @all_bind) = $self->insert(@old_args);

  if ($on_conflict && keys %$on_conflict > 0) {
    my (@set);
    puke "Unsupported data type specified to \$sql->upsert"
      unless ref $on_conflict eq 'HASH';
    #Copied from SQL::Abstract::More::_overridden_update
    for my $k (sort keys %$on_conflict) {
      my $v = $on_conflict->{$k};
      my $r = ref $v;
      my $label = $self->_quote($k);

      $self->_SWITCH_refkind($v, {
        ARRAYREF => sub {
          if ($self->{array_datatypes}
              || $self->is_bind_value_with_type($v)) {
            push @set, "$label = ?";
            push @all_bind, $self->_bindtype($k, $v);
          }
          else {                          # literal SQL with bind
            puke "Unsupported data type specified to \$sql->upsert"
          }
        },
        ARRAYREFREF => sub { # literal SQL with bind
          my ($sql, @bind) = @${$v};
          $self->_assert_bindval_matches_bindtype(@bind);
          push @set, "$label = $sql";
          push @all_bind, @bind;
        },
        SCALARREF => sub {  # literal SQL without bind
          push @set, "$label = $$v";
        },
        HASHREF => sub {
          my ($op, $arg, @rest) = %$v;

          puke 'Operator calls in update must be in the form { -op => $arg }'
            if (@rest or not $op =~ /^\-(.+)/);

          local $self->{_nested_func_lhs} = $k;
          my ($sql, @extra_bind) = $self->_where_unary_op ($1, $arg);

          push @set, "$label = $sql";
          push @all_bind, @extra_bind;
        },
        SCALAR_or_UNDEF => sub {
          push @set, "$label = ?";
          push @all_bind, $self->_bindtype($k, $v);
        },
      });
    }
    $sql .= " ON DUPLICATE KEY UPDATE " . join( ', ', @set);
  }

  return ($sql, @all_bind);
}


sub _insert_values {
  my ($self, $data) = @_;

  my (@values, @all_bind);
  foreach my $column (sort keys %$data) {
    my ($values, @bind) = $self->_insert_value($column, $data->{$column});
    push @values, $values;
    push @all_bind, @bind;
  }
  my $sql = $self->_sqlcase('values')." ( ".join(", ", @values)." )";
  return ($sql, @all_bind);
}

sub _insert_value {
  my ($self, $column, $v) = @_;

  my (@values, @all_bind);
  $self->_SWITCH_refkind($v, {

    ARRAYREF => sub {
      if ($self->{array_datatypes}) { # if array datatype are activated
        push @values, '?';
        push @all_bind, $self->_bindtype($column, $v);
      }
      else {                  # else literal SQL with bind
        puke "Unsupported data type specified to \$sql->insert"
      }
    },

    ARRAYREFREF => sub {        # literal SQL with bind
      my ($sql, @bind) = @${$v};
      $self->_assert_bindval_matches_bindtype(@bind);
      push @values, $sql;
      push @all_bind, @bind;
    },

    # THINK: anything useful to do with a HASHREF ?
    HASHREF => sub {       # (nothing, but old SQLA passed it through)
      #TODO in SQLA >= 2.0 it will die instead
      belch "HASH ref as bind value in insert is not supported";
      push @values, '?';
      push @all_bind, $self->_bindtype($column, $v);
    },

    SCALARREF => sub {          # literal SQL without bind
      push @values, $$v;
    },

    SCALAR_or_UNDEF => sub {
      push @values, '?';
      push @all_bind, $self->_bindtype($column, $v);
    },

  });

  my $sql = join(", ", @values);
  return ($sql, @all_bind);
}

sub update {
  my $self = shift;

  my @old_API_args;
  my %args;
  if (&_called_with_named_args) {
    %args = validate(@_, \%params_for_update);
    if (ref $args{-table} eq 'ARRAY' && $args{-table}[0] eq '-join') {
      my @join_args = @{$args{-table}};
      shift @join_args;           # drop initial '-join'
      my $join_info   = $self->join(@join_args);
      $args{-table} = \($join_info->{sql});
    }
    @old_API_args = @args{qw/-table -set -where/};
  }
  else {
    @old_API_args = @_;
  }

  # call clone of parent method
  my ($sql, @bind) = $self->_overridden_update(@old_API_args);

  # maybe need to handle additional args
  $self->_handle_additional_args_for_update_delete(\%args, \$sql, \@bind);

  return ($sql, @bind);
}

sub merge_conditions {
  my $self = shift;
  my %merged;

  foreach my $cond (@_) {
    if    (does($cond, 'HASH'))  {
      foreach my $col (sort keys %$cond) {
        my $curr = $cond->{$col};
        if (exists $merged{$col}) {
            my $prev = $merged{$col};
            if (defined $prev && defined $curr && !ref $prev && !ref $curr && ($prev eq $curr)) {
                next;
            } else {
                $merged{$col} = $prev ? [-and => $prev, $curr] : $curr;
            }
        } else {
            $merged{$col} = $curr;
        }
      }
    }
    elsif (does($cond, 'ARRAY') || does($cond, 'REF')) {
      $merged{-nest} = $merged{-nest} ? {-and => [$merged{-nest}, $cond]}
                                      : $cond;
    }
    elsif ($cond) {
      $merged{$cond} = \"";
    }
  }
  return \%merged;
}

sub _overridden_update {
  # unfortunately, we can't just override the ARRAYREF part, so the whole
  # parent method is copied here

  my $self  = shift;
  my $table = $self->_table(shift);
  my $data  = shift || return;
  my $where = shift;

  # first build the 'SET' part of the sql statement
  my (@set, @all_bind);
  puke "Unsupported data type specified to \$sql->update"
    unless ref $data eq 'HASH';

  for my $k (sort keys %$data) {
    my $v = $data->{$k};
    my $r = ref $v;
    my $label = $self->_quote($k);

    $self->_SWITCH_refkind($v, {
      ARRAYREF => sub {
        if ($self->{array_datatypes}
            || $self->is_bind_value_with_type($v)) {
          push @set, "$label = ?";
          push @all_bind, $self->_bindtype($k, $v);
        }
        else {                          # literal SQL with bind
          puke "Unsupported data type specified to \$sql->insert"
        }
      },
      ARRAYREFREF => sub { # literal SQL with bind
        my ($sql, @bind) = @${$v};
        $self->_assert_bindval_matches_bindtype(@bind);
        push @set, "$label = $sql";
        push @all_bind, @bind;
      },
      SCALARREF => sub {  # literal SQL without bind
        push @set, "$label = $$v";
      },
      HASHREF => sub {
        my ($op, $arg, @rest) = %$v;

        puke 'Operator calls in update must be in the form { -op => $arg }'
          if (@rest or not $op =~ /^\-(.+)/);

        local $self->{_nested_func_lhs} = $k;
        my ($sql, @bind) = $self->_where_unary_op ($1, $arg);

        push @set, "$label = $sql";
        push @all_bind, @bind;
      },
      SCALAR_or_UNDEF => sub {
        push @set, "$label = ?";
        push @all_bind, $self->_bindtype($k, $v);
      },
    });
  }

  # generate sql
  my $sql = $self->_sqlcase('update') . " $table " . $self->_sqlcase('set ')
          . CORE::join ', ', @set;

  if ($where) {
    my($where_sql, @where_bind) = $self->where($where);
    $sql .= $where_sql;
    push @all_bind, @where_bind;
  }

  return wantarray ? ($sql, @all_bind) : $sql;
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

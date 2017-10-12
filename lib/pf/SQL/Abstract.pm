package pf::SQL::Abstract;

=head1 NAME

pf::SQL::Abstract - PacketFence SQL::Abstract

=cut

=head1 DESCRIPTION

pf::SQL::Abstract

=cut

use strict;
use warnings;
use parent qw(SQL::Abstract::More);
use MRO::Compat;
use mro 'c3'; # implements next::method

use Params::Validate  qw/validate SCALAR SCALARREF CODEREF ARRAYREF HASHREF
                                  UNDEF  BOOLEAN/;
use Carp;                                  

BEGIN {
    *puke = \&SQL::Abstract::puke;
    *_called_with_named_args = \&SQL::Abstract::More::_called_with_named_args;
}

use namespace::clean;

my %params_for_upsert = (
  -into         => {type => SCALAR},
  -values       => {type => SCALAR|ARRAYREF|HASHREF},
  -on_conflict  => {type => HASHREF, optional => 1},
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
  my ($sql, @bind) = $self->insert(@old_args);

  if ($on_conflict && keys %$on_conflict > 0) {
    my (@set);
    puke "Unsupported data type specified to \$sql->upsert"
      unless ref $on_conflict eq 'HASH';
    #Copied from SQL::Abstract update
    for my $k (sort keys %$on_conflict) {
      my $v = $on_conflict->{$k};
      my $r = ref $v;
      my $label = $self->_quote($k);

      $self->_SWITCH_refkind($v, {
        ARRAYREF => sub {
          if ($self->{array_datatypes}) { # array datatype
            push @set, "$label = ?";
            push @bind, $self->_bindtype($k, $v);
          }
          else {                          # literal SQL with bind
            my ($sql, @b) = @$v;
            $self->_assert_bindval_matches_bindtype(@bind);
            push @set, "$label = $sql";
            push @bind, @b;
          }
        },
        ARRAYREFREF => sub { # literal SQL with bind
          my ($sql, @b) = @${$v};
          $self->_assert_bindval_matches_bindtype(@b);
          push @set, "$label = $sql";
          push @bind, @b;
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
          push @bind, @extra_bind;
        },
        SCALAR_or_UNDEF => sub {
          push @set, "$label = ?";
          push @bind, $self->_bindtype($k, $v);
        },
      });
    }
    $sql .= " ON DUPLICATE KEY UPDATE " . join( ', ', @set);
  }

  return ($sql, @bind);
}


 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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


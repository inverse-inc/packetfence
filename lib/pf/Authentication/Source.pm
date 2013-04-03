package pf::Authentication::Source;

=head1 NAME

pf::Authentication::Source

=head1 DESCRIPTION

We must at least always have one rule defined, the fallback one.

=cut

use Moose;
use pf::Authentication::constants;
use pf::Authentication::Action;

has 'id' => (isa => 'Str', is => 'rw', required => 1);
has 'unique' => (isa => 'Bool', is => 'ro', default => 0);
has 'type' => (isa => 'Str', is => 'ro', default => 'generic', required => 1);
has 'description' => (isa => 'Str', is => 'rw', required => 0);
has 'rules' => (isa => 'ArrayRef', is => 'rw', required => 0);

sub add_rule {
  my ($self, $rule) = @_;
  push(@{$self->{'rules'}}, $rule);
}

sub available_attributes {
  my $self = shift;
  return $self->common_attributes();
}

=head2 available_actions

Return all possible actions for a source. This method can be overloaded in a subclass to limit the available actions.

=cut

sub available_actions {
    return \@Actions::ACTIONS;
}

sub common_attributes {
  my $self = shift;
  return [
          { value => 'SSID', type => $Conditions::SUBSTRING },
          { value => 'current_time', type => $Conditions::TIME },
          { value => 'connection_type', type => $Conditions::CONNECTION },
          { value => 'computer_name', type => $Conditions::SUBSTRING },
         ];
}

sub authenticate {
  my $self = shift;

  return 0;
}

sub getRule {
    my ($self, $id) = @_;

    my $result;
    if ($id) {
        foreach my $rule (@{$self->{rules}}) {
            if ($rule->{id} eq $id) {
                $result = $rule;
            }
        }
    }
    else {
        $result = $self->{rules};
    }

    return $result;
}

=head2 match

The first rule for which its conditions are matched wins, and stops everything.

Subclasses will implement this method.

params is a hash of things to match. "username" is a mandatory attribute, but it
might also contain the "SSID", etc..

Returns the actions of the first matched rule.

=cut

sub match {
    my ( $self, $params ) = @_;
    my $common_attributes = $self->common_attributes();

    my $logger = Log::Log4perl->get_logger( __PACKAGE__ );

    my @matching_rules = ();

    foreach my $rule ( @{$self->{'rules'}} ) {
        my @matching_conditions = ();
        my @own_conditions = ();
        if (!defined $rule->{'conditions'} || scalar @{$rule->{'conditions'}} == 0) {
            push(@matching_rules, $rule);
            goto done;
        }

        foreach my $condition ( @{$rule->{'conditions'}} ) {
            if (grep {$_->{value} eq $condition->attribute } @$common_attributes) {
                my $r = $self->match_condition($condition, $params);

                if ($r == 1) {
                    push(@matching_conditions, $condition);
                }
            } elsif (grep {$_->{value} eq $condition->attribute } @{$self->available_attributes()}) {
                push(@own_conditions, $condition);
            }
        } # foreach my $condition (...)

        $self->match_in_subclass($params, $rule, \@own_conditions, \@matching_conditions);

        # We compare the matched conditions with how many we had
        if ($rule->match eq $Rules::ANY &&
            scalar @matching_conditions > 0) {
            push(@matching_rules, $rule);
        } elsif ($rule->match eq $Rules::ALL &&
                 scalar @matching_conditions == scalar @{$rule->{'conditions'}}) {
            push(@matching_rules, $rule);
        }

        # For now, we return the first matching rule. We might change this in the future
        # so let's keep the @matching_rules array for now.
        done:
        if (scalar @matching_rules == 1) {
            $logger->info("Matched rule ($rule->{'id'}), returning actions.");
            return $rule->{'actions'};
        }

    } # foreach my $rule ( @{$self->{'rules'}} ) {

    return undef;
}

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;

    return undef;
}

sub match_condition {
  my ($self, $condition, $params) = @_;

  my $r = 0;

  if (grep {$_->{value} eq $condition->attribute } @{$self->common_attributes()}) {
    $r = $condition->matches($condition->attribute, $params->{$condition->attribute});
  }

  return $r;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

__PACKAGE__->meta->make_immutable;
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

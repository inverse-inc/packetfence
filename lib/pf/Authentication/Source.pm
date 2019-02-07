package pf::Authentication::Source;

=head1 NAME

pf::Authentication::Source

=head1 DESCRIPTION

We must at least always have one rule defined, the fallback one.

=cut

use pf::log;
use pf::config;
use pf::constants;
use Moose;
use pf::util;
use pf::Authentication::constants;
use pf::Authentication::Action;
use List::Util qw(none);

has 'id' => (isa => 'Str', is => 'rw', required => 1);

# 'unique' attribute indicates that only one authentication source of this type can be configured
has 'unique' => (isa => 'Bool', is => 'ro', default => 0);

has 'class' => (isa => 'Str', is => 'ro', default => 'internal');

has 'type' => (isa => 'Str', is => 'ro', default => 'generic', required => 1);

has 'description' => (isa => 'Str', is => 'rw', required => 0);

has 'dynamic_routing_module' => (is => 'rw', default => 'AuthModule');

has 'rules' => (isa => 'ArrayRef', is => 'rw', required => 0, default => sub { [] });

=head2 has_authentication_rules

Whether or not the source should have authentication rules

=cut

sub has_authentication_rules { $TRUE }

=head2 add_rule

=cut

sub add_rule {
  my ($self, $rule) = @_;
  push(@{$self->{'rules'}}, $rule);
}

=head2 available_attributes

=cut

sub available_attributes {
  my $self = shift;
  return $self->common_attributes();
}

=head2 available_rule_classes

Return all possible rule classes for a source. This method can be overloaded in a subclass to limit the available rule classes.

=cut

sub available_rule_classes {
    return \@Rules::CLASSES;
}

=head2 available_actions

Return all possible actions for a source. This method can be overloaded in a subclass to limit the available actions.

Defined in pf::Authentication::constants.

=cut

sub available_actions {
    my @actions = map( { @$_ } values %Actions::ACTIONS);
    return \@actions;
}

=head2 common_attributes

=cut

sub common_attributes {
  my $self = shift;
  return [
          { value => 'SSID', type => $Conditions::SUBSTRING },
          { value => 'current_time', type => $Conditions::TIME },
          { value => 'current_time_period', type => $Conditions::TIME_PERIOD },
          { value => 'connection_type', type => $Conditions::CONNECTION },
          { value => 'computer_name', type => $Conditions::SUBSTRING },
          { value => "mac", type => $Conditions::SUBSTRING },
          { value => "realm", type => $Conditions::SUBSTRING },
         ];
}

=head2 authenticate

=cut

sub authenticate {
  my $self = shift;

  return 0;
}

=head2 getRule

=cut

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


=head2 getDefaultOfType

Get the default value of a type

=cut

sub getDefaultOfType {
    my ($self) = @_;
    return $self->meta->get_attribute('type')->default;
}


=head2 match

The first rule for which its conditions are matched wins, and stops everything.

Subclasses will implement this method.

params is a hash of things to match. "username" is a mandatory attribute, but it
might also contain the "SSID", etc..

Returns the actions of the first matched rule.

=cut

sub match {
    my ($self, $params, $action, $extra) = @_;

    my $logger = get_logger();
    my %allowed_actions;
    if (defined $action && exists $Actions::ALLOWED_ACTIONS{$action}) {
        %allowed_actions = %{$Actions::ALLOWED_ACTIONS{$action}};
    }

    # Add current date & time to the list of parameters
    my $time = time;
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime($time);
    my $current_date = sprintf("%d-%02d-%02d", $year+1900, $mon+1, $mday);
    my $current_time = sprintf("%02d:%02d", $hour, $min);
    # Make a copy of the keys to allow caching of the parameters
    $params = {%$params};
    my $rule_class = $params->{'rule_class'} // '';
    $params->{current_date} //= $current_date;
    $params->{current_time} //= $current_time;
    $params->{current_time_period} //= $time;

    $self->preMatchProcessing;

    foreach my $rule ( @{$self->{'rules'}} ) {
        if ( ($rule_class ne $rule->{'class'}) || (defined $action && none { $allowed_actions{$_->type} } @{$rule->{actions}}) ) {
            $logger->trace("Skipping rule " . ($rule->id ) . " for source " . $self->id);
            next;
        }

        if ($self->match_rule($rule, $params, $extra)) {
            $logger->info("Matched rule (".$rule->{'id'}.") in source ".$self->id.", returning actions.");
            $self->postMatchProcessing;
            return $rule->{'actions'};
        }

    } # foreach my $rule ( @{$self->{'rules'}} ) {
    $self->postMatchProcessing;

    return undef;
}

sub match_rule {
    my ($self, $rule, $params, $extra) = @_;
    my $logger = get_logger();
    my @matching_conditions = ();
    my @own_conditions = ();
    my $common_attributes = $self->common_attributes();
    my $available_attributes = $self->available_attributes();
    my @matching_rules = ();

    foreach my $condition ( @{$rule->{'conditions'}} ) {
        if (grep { $_->{value} eq $condition->attribute } @$common_attributes) {
            # A condition on a common attribute
            my $r = $self->match_condition($condition, $params);

            if ($r) {
                $logger->debug("Matched condition ".join(" ", ($condition->attribute, $condition->operator, $condition->value)));
                push(@matching_conditions, $condition);
            }
        }
        elsif (grep { $_->{value} eq $condition->attribute } @$available_attributes) {
            # A condition on a source-specific attribute
            push(@own_conditions, $condition);
        }
    } # foreach my $condition (...)

    # We always check if at least the returned value is defined. That means the username
    # has been found in the source.
    if (defined $self->match_in_subclass($params, $rule, \@own_conditions, \@matching_conditions, $extra)) {
      # We compare the matched conditions with how many we had
      if ($rule->match eq $Rules::ANY &&
          scalar @matching_conditions > 0) {
          push(@matching_rules, $rule);
      } elsif ($rule->match eq $Rules::ALL &&
               scalar @matching_conditions == scalar @{$rule->{'conditions'}}) {
          push(@matching_rules, $rule);
      }
    }

    # For now, we return the first matching rule. We might change this in the future
    # so let's keep the @matching_rules array for now.
    if (scalar @matching_rules == 1) {
        $logger->info("Matched rule (".$rule->{'id'}.") in source ".$self->id.", returning actions.");
        return $TRUE;
    }
    return $FALSE;
}

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;

    return undef;
}

=head2 match_condition

=cut

sub match_condition {
  my ($self, $condition, $params) = @_;

  my $r = $condition->matches($condition->attribute, $params->{$condition->attribute});

  return $r;
}

=head2 search_attributes

=cut

sub search_attributes {
    my ($self,$username) = @_;
    return $self->search_attributes_in_subclass($username);
}

=head2 search_attributes_in_subclass

Search for the attributes of a user

Returns a hashref that will be injected in pf::person::modify or 0 ($FALSE) if it fails

=cut

sub search_attributes_in_subclass {
    my $logger = get_logger();
    $logger->debug("search_attributes_in_subclass is not supported on this source.");
    return $FALSE;
}

=head2 postMatchProcessing

Tear down any resources created in preMatchProcessing

=cut

sub postMatchProcessing { }

=head2 preMatchProcessing

Setup any resouces need for matching

=cut

sub preMatchProcessing { }

=head2 mandatoryFields

List of mandatory fields for this source

=cut

sub mandatoryFields {}


=head2 realmIsAllowed

checks if realm is allowed

=cut

sub realmIsAllowed {
    my ($self, $realm) = @_;
    return $FALSE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

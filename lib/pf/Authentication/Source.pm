=item

We must at least always have one rule defined, the fallback one.

=cut
package pf::Authentication::Source;
use Moose;

use pf::config qw($TRUE $FALSE);

has 'id' => (isa => 'Str', is => 'rw', required => 1);
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

sub common_attributes {
  my $self = shift;
  return ["SSID"];
}

sub authenticate {
  my $self = shift;

  return 0;
}

=item

This will first try to match "standard" attributes with conditions of rules.

The first rule for which its conditions are matched wins, and stops everything.

params is a hash or things to match. "username" is a mandatory attribute, but it
might also contain the "SSID", etc..

The logic here is simple. If the match is ANY, the first condition matched stops everything.
If the match is ALL, we run through all conditions of all rules but ONLY for the attributes
that are "generic" (SSID, etc.).

RETURNS the matched rules, empty array if someone forgot to define the catchall!

=cut
sub match {
  my ($self, $params) = @_;

  my $common_attributes = $self->common_attributes();
  my @matching_rules = ();

  foreach my $rule ( @{$self->{'rules'}} ) {
    my $result = 0;
    
    foreach my $condition ( @{$rule->{'conditions'}} ) {
      print "Got attribute: " . $condition->attribute . "\n";
      print "Value from params: " . $params->{$condition->attribute} . "\n";
      if (grep {$_ eq $condition->attribute } @$common_attributes) {
	
	my $r = $condition->matches($condition->attribute, $params->{$condition->attribute});

	if ($rule->match eq Rule->ANY) {
	  $result = $result | $r;

	  # If a condition matches and we are matching ANY, let's stop evaluating all conditions
	  if ($result == 1) {
	    last;
	  }
	} else {
	  $result = $result & $r;
       	}
      }
    }
    
    # If we ran all conditions and we have matched them sucessfully, let's return the rule
    if ($result == 1) {
      push(@matching_rules, $rule);
    }
  }
  
  print "Returning $#matching_rules rules\n";
  return \@matching_rules;
}

=back

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

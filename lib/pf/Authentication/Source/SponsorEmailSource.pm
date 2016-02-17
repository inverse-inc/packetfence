package pf::Authentication::Source::SponsorEmailSource;

=head1 NAME

pf::Authentication::Source::SponsorEmailSource

=head1 DESCRIPTION

=cut

use pf::Authentication::constants;

use Moose;
extends 'pf::Authentication::Source';

has '+class' => (default => 'external');
has '+type' => (default => 'SponsorEmail');
has '+unique' => (default => 1);
has '+dynamic_routing_module' => (default => 'AuthModule::Sponsor');
has 'allow_localdomain' => (isa => 'Str', is => 'rw', default => 'yes');
has 'create_local_account' => (isa => 'Str', is => 'rw', default => 'no');
has 'activation_domain' => (isa => 'Maybe[Str]', is => 'rw');

=head2 available_attributes

Allow to make a condition on the user's email address.

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my $own_attributes = [{ value => "user_email", type => $Conditions::SUBSTRING }];

  return [@$super_attributes, @$own_attributes];
}

=head2 available_rule_classes

SponsorEmail sources only allow 'authentication' rules

=cut

sub available_rule_classes {
    return [ grep { $_ ne $Rules::ADMIN } @Rules::CLASSES ];
}

=head2 available_actions

For a SponsorEmail source, only the authentication actions should be available

=cut

sub available_actions {
    my @actions = map( { @$_ } $Actions::ACTIONS{$Rules::AUTH});
    return \@actions;
}

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    return $params->{'username'};
}

=head2 mandatoryFields

List of mandatory fields for this source

=cut

sub mandatoryFields {
    return qw(email sponsor);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

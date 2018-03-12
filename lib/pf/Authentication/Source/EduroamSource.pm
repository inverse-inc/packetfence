package pf::Authentication::Source::EduroamSource;

=head1 NAME

pf::Authentication::Source::EduroamSource

=head1 DESCRIPTION

=cut

use pf::Authentication::constants;
use pf::constants qw($TRUE $FALSE);
use pf::log;

use Moose;
extends 'pf::Authentication::Source';

has '+type'                 => (default => 'Eduroam');
has '+class'                => (isa => 'Str', is => 'ro', default => 'exclusive');
has '+unique'               => (isa => 'Bool', is => 'ro', default => $TRUE);
has 'server1_address'       => (isa => 'Str', is => 'rw');
has 'server2_address'       => (isa => 'Str', is => 'rw');
has 'radius_secret'         => (isa => 'Str', is => 'rw');
has 'auth_listening_port'   => (isa => 'Maybe[Int]', is => 'rw', default => '11812');
has 'local_realm'           => (isa => 'ArrayRef[Str]', is => 'rw');
has 'reject_realm'          => (isa => 'ArrayRef[Str]', is => 'rw');
has 'monitor' => ( isa => 'Bool', is => 'rw', default => 1 );

=head2 available_rule_classes

Eduroam source only allow 'authentication' rules

=cut

sub available_rule_classes {
    return [ grep { $_ ne $Rules::ADMIN } @Rules::CLASSES ];
}


=head2 available_actions

Eduroam source only allow 'authentication' actions

=cut

sub available_actions {
    my @actions = map( { @$_ } $Actions::ACTIONS{$Rules::AUTH});
    return \@actions;
}


=head2 available_attributes

Allow to make a condition on the user's username.

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my $own_attributes = [{ value => "username", type => $Conditions::SUBSTRING }];

  return [@$super_attributes, @$own_attributes];
}


=head2 match_in_subclass

Should always "match" and allow specific conditions

=cut

sub match_in_subclass {
    my ( $self, $params, $rule, $own_conditions, $matching_conditions ) = @_;
    my $username = $params->{'username'};

    foreach my $condition ( @{ $own_conditions } ) {
        if ( $condition->{'attribute'} eq "username" ) {
            if ( $condition->matches("username", $username) ) {
                push(@{ $matching_conditions }, $condition);
            }
        }
    }

    return $username;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

package pf::Authentication::Source::EmailSource;

=head1 NAME

pf::Authentication::Source::EmailSource

=head1 DESCRIPTION

=cut

use pf::Authentication::constants;
use pf::constants qw($TRUE $FALSE);
use pf::constants::authentication::messages;
use pf::log;

use Moose;
extends 'pf::Authentication::Source';
with qw(
    pf::Authentication::CreateLocalAccountRole
    pf::Authentication::EmailFilteringRole
);

has '+class' => (default => 'external');
has '+type' => (default => 'Email');
has 'email_activation_timeout' => (isa => 'Str', is => 'rw', default => '10m');
has 'activation_domain' => (isa => 'Maybe[Str]', is => 'rw');

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Email' }

=head2 available_attributes

Allow to make a condition on the user's email address.

=cut

sub available_attributes {
    my $self = shift;
    return [
        @{ $self->SUPER::available_attributes },
        { value => "user_email", type => $Conditions::SUBSTRING }
    ];
}

=head2 available_rule_classes

Email sources only allow 'authentication' rules

=cut

sub available_rule_classes {
    return [ grep { $_ ne $Rules::ADMIN } @Rules::CLASSES ];
}

=head2 available_actions

For an Email source, only the authentication actions should be available

=cut

sub available_actions {
    my @actions = map( { @$_ } $Actions::ACTIONS{$Rules::AUTH});
    return \@actions;
}

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    foreach my $condition (@{ $own_conditions }) {
        if ($condition->{'attribute'} eq "user_email") {
            if ( $condition->matches("user_email", $params->{user_email}) ) {
                push(@{ $matching_conditions }, $condition);
                return $params->{user_email};
            }
        }
    }
    return $params->{'username'};
}

=head2 mandatoryFields

List of mandatory fields for this source

=cut

sub mandatoryFields {
    return qw(email);
}


=head2 authenticate

=cut

sub authenticate {
    my ( $self, $username, $password ) = @_;
    if (!$self->isEmailAllowed($username)) {
        my $logger = get_logger();
        $logger->warn("EmailSource ($self->{id}) failed to authenticate PID '$username' is banned");
        return ($FALSE, $pf::constants::authentication::messages::EMAIL_UNAUTHORIZED);
    }

    return $TRUE;
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

package pf::Authentication::Source::OAuthSource;

=head1 NAME

pf::Authentication::Source::OAuthSource

=head1 DESCRIPTION

Abstract class for OAuth sources.

=cut

use pf::log;
use Moose;
extends 'pf::Authentication::Source';

has '+class' => (default => 'abstact');
has '+type' => (default => 'OAuth');

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::OAuth' }

=head2 available_rule_classes

OAuth sources only allow 'authentication' rules

=cut

sub available_rule_classes {
    return [ grep { $_ ne $Rules::ADMIN } @Rules::CLASSES ];
}

=head2 available_actions

For an OAuth source, only the authentication actions should be available

=cut

sub available_actions {
    my @actions = map( { @$_ } $Actions::ACTIONS{$Rules::AUTH});
    return \@actions;
}

=head2 available_attributes

=cut

sub available_attributes {
    my $self = shift;
    return([@{$self->SUPER::available_attributes}, {value => 'username', type => $Conditions::SUBSTRING }]);
}

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    my $username =  $params->{'username'};
    foreach my $condition (@{ $own_conditions }) {
        if ($condition->{'attribute'} eq "username") {
            if ( $condition->matches("username", $username) ) {
                push(@{ $matching_conditions }, $condition);
            }
        }
    }
    return $username;
}

=head2 lookup_from_provider_info

Lookup the person information from the authentication hash received during the OAuth process

=cut

sub lookup_from_provider_info {
    my ( $self, $pid, $info ) = @_;
    my $logger = get_logger();
    $logger->warn("Provider information lookup is not implemented on this OAuth source.");
}

=head2 additional_client_attributes

Provide a hook for additional attributes to be passed to the auth source

=cut

sub additional_client_attributes { }

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

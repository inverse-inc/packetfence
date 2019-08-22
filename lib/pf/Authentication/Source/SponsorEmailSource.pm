package pf::Authentication::Source::SponsorEmailSource;

=head1 NAME

pf::Authentication::Source::SponsorEmailSource

=head1 DESCRIPTION

=cut

use Moose;

use pf::Authentication::constants;
use pf::config qw(%Config);
use pf::constants qw($TRUE $FALSE);
use pf::constants::authentication::messages;
use pf::log;
use pf::util;

extends 'pf::Authentication::Source';
with qw(
    pf::Authentication::CreateLocalAccountRole
    pf::Authentication::EmailFilteringRole
);

has '+class' => (default => 'external');
has '+type' => (default => 'SponsorEmail');
has 'activation_domain' => (isa => 'Maybe[Str]', is => 'rw');
has 'sponsorship_bcc' => (isa => 'Maybe[Str]', is => 'rw');
has 'email_activation_timeout' => (isa => 'Str', is => 'rw', default => '30m');
has 'validate_sponsor' => (isa => 'Str', is => 'rw', default => 'yes');
has 'lang' => (isa => 'Maybe[Str]', is => 'rw', default => '');
has 'sources' => (isa => 'ArrayRef[Str]', is => 'rw');

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Sponsor' }

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


=head2 authenticate

=cut

sub authenticate {
    my ( $self, $username, $password ) = @_;
    my $logger = pf::log::get_logger;

    my $localdomain = $Config{'general'}{'domain'};

    # Verify if allowed to use local domain
    unless ( isenabled($self->allow_localdomain) ) {
        if ( $username =~ /[@.]$localdomain$/i ) {
            $logger->warn("Tried to authenticate using SponsorEmailSource with PID '$username' matching local domain '$localdomain' while 'allow_localdomain' is disabled");
            return ($FALSE, $pf::constants::authentication::messages::LOCALDOMAIN_EMAIL_UNAUTHORIZED);
        }
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

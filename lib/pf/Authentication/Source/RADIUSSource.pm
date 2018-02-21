package pf::Authentication::Source::RADIUSSource;

=head1 NAME

pf::Authentication::Source::RADIUSSource

=head1 DESCRIPTION

=cut

use pf::constants qw($TRUE $FALSE);
use pf::Authentication::constants qw($LOGIN_CHALLENGE);
use pf::constants::authentication::messages;
use pf::log;
use pf::config qw(%Config);

our $RADIUS_STATE = 'State';
our $RADIUS_REPLY_MESSAGE = 'Reply-Message';
our $RADIUS_ERROR_NONE = 'ENONE';

use Authen::Radius;
Authen::Radius->load_dictionary("/usr/share/freeradius/dictionary");

use Moose;
extends 'pf::Authentication::Source';
with qw(pf::Authentication::InternalRole);

has '+type' => ( default => 'RADIUS' );
has 'host' => (isa => 'Maybe[Str]', is => 'rw', default => '127.0.0.1');
has 'port' => (isa => 'Maybe[Int]', is => 'rw', default => 1812);
has 'timeout' => (isa => 'Maybe[Int]', is => 'rw', default => 1);
has 'secret' => (isa => 'Str', is => 'rw', required => 1);
has 'monitor' => ( isa => 'Bool', is => 'rw', default => 1 );

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Login' }

=head2 available_attributes

Add additional available attributes

=cut

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes;
  my @attributes = @{$Config{advanced}->{radius_attributes}};
  my @radius_attributes = map { { value => $_, type => $Conditions::SUBSTRING } } @attributes;
  return [@$super_attributes, @radius_attributes];
}

=head2  authenticate

=cut

sub authenticate {
    my ($self, $username, $password) = @_;
    return $self->_send_radius_auth($username, $password);
}

=head2 challenge

Send the a radius authentication with challenge state

=cut

sub challenge {
    my ($self, $username, $password, $challenge_data) = @_;
    my $attribute = {
        Name  => $challenge_data->{state_code},
        Value => $challenge_data->{state},
        Type  => 'string'
    };
    return $self->_send_radius_auth($username, $password, $attribute);
}


=head2 _send_radius_auth

=cut

sub _send_radius_auth {
    my ($self, $username, $password, @attributes) = @_;
    my $logger = get_logger();

    my $radius = Authen::Radius->new(
        Host   => "$self->{'host'}:$self->{'port'}",
        Secret => $self->{'secret'},
        TimeOut => $self->{'timeout'},
    );

    if (!defined $radius) {
        $logger->error("Unable to perform RADIUS authentication on any server: " . Authen::Radius::get_error());
        return ($FALSE, $COMMUNICATION_ERROR_MSG);
    }

    my $result = $self->check_radius_password($radius, $username, $password, undef, @attributes);
    return $self->_handle_radius_request($radius, $result);
}

=head2 challenge_handle_radius_request

=cut

sub _handle_radius_request {
    my ($self, $radius, $result) = @_;
    my $logger = get_logger();
    if ($radius->get_error() ne $RADIUS_ERROR_NONE) {
        $logger->error("Unable to perform RADIUS authentication on any server: " . Authen::Radius::get_error());
        return ($FALSE, $COMMUNICATION_ERROR_MSG);
    }
    if ($result == ACCESS_ACCEPT) {
        return ($TRUE, $AUTH_SUCCESS_MSG, $self->_fetch_attributes($result, $radius));
    }
    elsif ($result == ACCESS_CHALLENGE) {
        return ($LOGIN_CHALLENGE, $self->_make_challenge_data($result, $radius));
    }
    return ($FALSE, $AUTH_FAIL_MSG);
}

=head2 _make_challenge_data

=cut

sub _make_challenge_data {
    my ($self, $result, $radius) = @_;
    my @attributes = $radius->get_attributes;
    my ($state_attribute) = grep { $_->{Name} eq  $RADIUS_STATE} @attributes;
    my ($message_attribute) = grep { $_->{Name} eq $RADIUS_REPLY_MESSAGE } @attributes;
    return {
        id         => $self->id,
        result     => $result,
        attributes => \@attributes,
        state      => $state_attribute->{RawValue},
        state_code => $state_attribute->{Code},
        message    => $message_attribute->{Value},
    };
}

=head2 _fetch_attributes

=cut

sub _fetch_attributes {
    my ($self, $result, $radius) = @_;
    my @attributes = $radius->get_attributes;
    return {
        attributes => \@attributes,
    };
}

=head2 check_radius_password

=cut

sub check_radius_password {
    my ($self, $radius, $name, $pwd, $nas, @extra) = @_;

    $nas = eval {$radius->{'sock'}->sockhost()} unless defined($nas);
    $radius->clear_attributes;
    $radius->add_attributes(
        {Name => 1, Value => $name, Type => 'string'},
        {Name => 2, Value => $pwd,  Type => 'string'},
        {Name => 4, Value => $nas || '127.0.0.1', Type => 'ipaddr'},
        @extra
    );

    $radius->send_packet(ACCESS_REQUEST);
    my $rcv = $radius->recv_packet();
    return $rcv;
}

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions, $extra) = @_;
    my $username =  $params->{'username'};

    foreach my $condition (@{ $own_conditions }) {
        if ($condition->{'attribute'} eq "username") {
            if ( $condition->matches("username", $username) ) {
                push(@{ $matching_conditions }, $condition);
            }
        }
        if (defined($extra)) {
            for my $attribute (@{ $extra->{attributes}} ) {
                if ($condition->{'attribute'} eq $attribute->{'Name'} ) {
                    if ( $condition->matches($condition->{'attribute'}, $attribute->{'Value'}) ) {
                        push(@{ $matching_conditions }, $condition);
                    }
                }
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

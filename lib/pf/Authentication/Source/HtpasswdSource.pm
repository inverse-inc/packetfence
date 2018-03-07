package pf::Authentication::Source::HtpasswdSource;

=head1 NAME

pf::Authentication::Source::HtpasswdSource

=head1 DESCRIPTION

=cut

use pf::constants qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::constants::authentication::messages;
use pf::Authentication::Source;
use pf::util;
use pf::log;

use Apache::Htpasswd;

use Moose;
extends 'pf::Authentication::Source';
with qw(pf::Authentication::InternalRole);

has '+type' => (default => 'Htpasswd');
has 'path' => (isa => 'Str', is => 'rw', required => 1);

=head1 METHODS

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Login' }

=head2 available_attributes

=cut

sub available_attributes {
    my $self = shift;

    my $super_attributes = $self->SUPER::available_attributes;
    my $own_attributes = [{ value => 'username', type => $Conditions::SUBSTRING }];

    return [@$super_attributes, @$own_attributes];
}

=head2 authenticate

=cut

sub authenticate {
    my ($self, $username, $password) = @_;

    my $logger = get_logger();
    my $password_file = $self->{'path'};

    if (! -r $password_file) {
        $logger->error("unable to read password file '$password_file'");
        return ($FALSE);
    }

    my $htpasswd = new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly   => 1});
    if ( (!defined($htpasswd->htCheckPassword($username, $password)))
         or ($htpasswd->htCheckPassword($username, $password) == 0) ) {

        return ($FALSE, $AUTH_FAIL_MSG);
    }

    return ($TRUE, $AUTH_SUCCESS_MSG);
}

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    local $_;

    # First check if the username is found in the htpasswd file
    my $username = $params->{'username'} || $params->{'email'};
    my $password_file = $self->{'path'};
    if ($username && -r $password_file) {
        my $htpasswd = new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly => 1});
        if ( $htpasswd->fetchPass($username) ) {
            # Username is defined in the htpasswd file
            # Let's match the htpasswd conditions alltogether.
            # We should only have conditions based on the username attribute.
            foreach my $condition (@{ $own_conditions }) {
                if ($condition->{'attribute'} eq "username") {
                    if ( $condition->matches("username", $username) ) {
                        push(@{ $matching_conditions }, $condition);
                    }
                }
            }
            return $username;
        }
    }

    return undef;
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

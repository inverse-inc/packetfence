package pf::cmd::pf::saml;
=head1 NAME

pf::cmd::pf::saml

=head1 SYNOPSIS

 pfcmd saml <command> <arguments>

Commands:

 testsource <sourceid>

=head1 DESCRIPTION

pf::cmd::pf::cache

=cut

use strict;
use warnings;
use pf::authentication;
use pf::constants::exit_code qw($EXIT_SUCCESS);
use base qw(pf::base::cmd::action_cmd);

=head1 METHODS

=head2 action_testsource

Handles the testsource action

=cut

sub action_testsource {
    my ($self) = @_;
    my ($sourceid) = $self->action_args;
    print "You should see the SSO URL below, otherwise, there are errors in your configuration: \n";
    print getAuthenticationSource($sourceid)->sso_url;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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



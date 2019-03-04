package pf::WebAPI::AuthenHandler;
=head1 NAME

pf::WebAPI::AuthenHandler

=cut

=head1 DESCRIPTION

pf::WebAPI::AuthenHandler provides the authentication for the webservice api

=cut

use strict;
use warnings;


use strict;
use warnings;

use Apache2::Access ();
use Apache2::RequestUtil ();
use Apache2::RequestRec;

use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);

use pf::config qw(%Config);
use pf::log;


=head1 METHODS

=head2 handler

apache handler for webservices authentication

=cut

sub handler {
    my $r = shift;
    my $status = Apache2::Const::OK;
    my ($webservices_user,$webservices_pass) = @{$Config{webservices}}{qw(user pass)};
    if(defined $webservices_user && $webservices_user ne '' && defined $webservices_pass && $webservices_pass ne '') {
        my $pass;
        ($status, $pass) = $r->get_basic_auth_pw;
        if ($status == Apache2::Const::OK) {
            my $user = $r->user;
            if ( defined $user && defined $pass &&
                    $webservices_user eq $user &&
                    $webservices_pass eq $pass  ) {
                return Apache2::Const::OK;
            }
        }
    }
    $r->note_basic_auth_failure;
    return Apache2::Const::HTTP_UNAUTHORIZED;
}

1;


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

1;


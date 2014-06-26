#!/usr/bin/perl
package pf::web::provisioning;

=head1 NAME

pf::web::provisioning - handle the provisioning client request

=cut

=head1 DESCRIPTION

pf::web::provisioning  return secure wifi profile for windows, apple and android device. 

=cut

use strict;
use warnings;

use Apache2::Const;
use Apache2::Request;
use Template;

use pf::config;
use pf::node;
use pf::web;
use pf::web::util;
use pf::Portal::Session;
use pf::util;
use pf::log;

=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = Log::Log4perl::get_logger("pf::web::provisioning");
   $logger->debug("instantiating new pf::web::provisioning");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item android_provisioning

This handler generate the xml provisioning profil for android stuff.

=cut

sub android_provisioning {
    my ($this, $r) = @_;
    my $req = Apache2::Request->new($r);
    my $logger = get_logger();

    my $portalSession = pf::Portal::Session->new();

    my $response;
    $response = pf::web::generate_mobileconfig_provisioning_xml($portalSession);
    $req->content_type('application/x-apple-aspen-config; charset=utf-8');
    $req->no_cache(1);
    $req->print($response);
    return Apache2::Const::OK;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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

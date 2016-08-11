#!/usr/bin/perl

=head1 NAME

assertion.cgi

=cut

=head1 DESCRIPTION

=cut

use strict;
use warnings;
use lib '/usr/local/pf/lib';

use CGI qw(:standard);
use JSON::MaybeXS;

use pf::authentication;

use Data::Dumper;
print STDERR Dumper("SOURCE ID : ".param("source_id"));
my $source_id = param("source_id");
my $saml_response = param("SAMLResponse");
my ($username, $msg) = getAuthenticationSource($source_id)->handle_response($saml_response);
print header(), encode_json({username => $username, msg => $msg});

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
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.

=cut

1;


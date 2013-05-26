package pf::pfdns::constants;

=head1 NAME

pf::pfdns::constants - Constants for the pfdns service

=head1 DESCRIPTION

This file is splitted by packages and refering to the constant requires you to
specify the package.

=cut
use strict;
use warnings;

use Readonly;

use pf::authentication;
use pf::config;

=head1 SUBROUTINES

=cut

=item oauth_domain

Build all the permit domain for oauth authentication

=cut

sub oauth_domain {

    my @domains;
    foreach my $source ( @authentication_sources ) {

        my $classname = $source->meta->name;

        if ($classname eq 'pf::Authentication::Source::GoogleSource') {

            push(@domains, split(',',$source->{'domains'}));

        }
    }

    return @domains;
}

=back

=head1 OAUTH

=cut
package OAUTH;

my @oauth_domains =  pf::pfdns::constants::oauth_domain();
foreach (@oauth_domains) { s{([^/])$}{$1\$} };
foreach (@oauth_domains) { s{(\*).(.*)}{\(\.\*\)\.$2} };

my $allow_oauth_domains = join('|', @oauth_domains) if (@oauth_domains ne '0');

if (defined($allow_oauth_domains)) {
    Readonly::Scalar our $ALLOWED_OAUTH_DOMAINS => qr/ ^(?: $allow_oauth_domains ) /xo; # eXtended pattern, compile Once
} else {
    Readonly::Scalar our $ALLOWED_OAUTH_DOMAINS => '';
}

=back

=head1 AUTHOR

Fabrice Durand <fdurand@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

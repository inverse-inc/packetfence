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
use pf::class qw(class_view_all);
use pf::util::apache qw(url_parser);

=head1 SUBROUTINES

=cut

=head2 oauth_domain

Build all the permit domain for oauth authentication

=cut

sub oauth_domain {

    my @domains;
    foreach my $source ( @authentication_sources ) {

        my $classname = $source->meta->name;

        if ( ($classname eq 'pf::Authentication::Source::GoogleSource') || ($classname eq 'pf::Authentication::Source::GithubSource') || ($classname eq 'pf::Authentication::Source::FacebookSource') ) {

            push(@domains, split(',',$source->{'domains'}));

        }
    }

    return @domains;
}

=head2 passthrough

Build all the permit domain for passthrough

=cut

sub passthrough { @{ $Config{trapping}{passthroughs} }; }

=head2 passthrough_remediation

Build all the permit domain for passthrough_remediation

=cut

sub passthrough_remediation {
    my @remediation_rules=class_view_all();
    my @domains;

    foreach my $row (@remediation_rules) {
        my $url = $row->{'url'};
        next if ( ( !defined($url) ) || ( $url =~ /^\// ) );
        my ($domainonly_url, $proto, $host, $query) = url_parser($url);
        push(@domains, $host);
    }
    return @domains;
}

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


=head1 PASSTHROUGH

=cut

package PASSTHROUGH;

my @passthrough_domains =  pf::pfdns::constants::passthrough();
foreach (@passthrough_domains) { s{([^/])$}{$1\$} };
foreach (@passthrough_domains) { s{(\*).(.*)}{\(\.\*\)\.$2} };

my $allow_passthrough_domains = join('|', @passthrough_domains) if (@passthrough_domains ne '0');

if (defined($allow_passthrough_domains)) {
    Readonly::Scalar our $ALLOWED_PASSTHROUGH_DOMAINS => qr/ ^(?: $allow_passthrough_domains ) /xo; # eXtended pattern, compile Once
} else {
    Readonly::Scalar our $ALLOWED_PASSTHROUGH_DOMAINS => '';
}

my @passthrough_remediation_domains =  pf::pfdns::constants::passthrough_remediation();
foreach (@passthrough_remediation_domains) { s{([^/])$}{$1\$} };
foreach (@passthrough_remediation_domains) { s{(\*).(.*)}{\(\.\*\)\.$2} };

my $allow_passthrough_remediation_domains = join('|', @passthrough_remediation_domains) if (@passthrough_remediation_domains ne '0');

if (defined($allow_passthrough_remediation_domains)) {
    Readonly::Scalar our $ALLOWED_PASSTHROUGH_REMEDIATION_DOMAINS => qr/ ^(?: $allow_passthrough_remediation_domains ) /xo; # eXtended pattern, compile Once
} else {
    Readonly::Scalar our $ALLOWED_PASSTHROUGH_REMEDIATION_DOMAINS => '';
}


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


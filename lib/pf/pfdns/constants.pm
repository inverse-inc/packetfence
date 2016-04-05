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
use pf::config qw(%Config);
use pf::class qw(class_view_all);
use pf::util::apache qw(url_parser);

=head1 SUBROUTINES

=cut

=head2 sources_domains

Build all the permit domain for oauth and billing authentication

=cut

sub sources_domains {

    my @domains;
    foreach my $source ( @authentication_sources ) {

        my $classname = $source->meta->name;

        if($source->class eq 'billing' && $source->can('domains')){
            push(@domains, split(',',$source->{'domains'}));
        }
        elsif ( ($classname eq 'pf::Authentication::Source::GoogleSource') || ($classname eq 'pf::Authentication::Source::GithubSource') || ($classname eq 'pf::Authentication::Source::FacebookSource') || ($classname eq 'pf::Authentication::Source::LinkedInSource') || ($classname eq 'pf::Authentication::Source::WindowsLiveSource') || ($classname eq 'pf::Authentication::Source::TwitterSource')) {
            push(@domains, split(',',$source->{'domains'}));

        }
    }

    return @domains;
}

=head2 passthrough

Build all the permit domain for passthrough

=cut

sub passthrough { @{ $Config{trapping}{passthroughs} }; }

=head1 OAUTH

=cut

package OAUTH;

my @sources_domains =  pf::pfdns::constants::sources_domains();
foreach (@sources_domains) { s{^([\d+|\w+](.*))}{\Q$1\E} };
foreach (@sources_domains) { s{(\*)(.*)}{\(\.\*\)\Q$2\E} };
foreach (@sources_domains) { s{([^/])$}{$1\$} };

my $allow_sources_domains = join('|', @sources_domains) if (@sources_domains ne '0');

if (defined($allow_sources_domains)) {
    Readonly::Scalar our $ALLOWED_SOURCES_DOMAINS => qr/ ^(?: $allow_sources_domains ) /xo; # eXtended pattern, compile Once
} else {
    Readonly::Scalar our $ALLOWED_SOURCES_DOMAINS => '';
}


=head1 PASSTHROUGH

=cut

package PASSTHROUGH;

my @passthrough_domains =  pf::pfdns::constants::passthrough();
foreach (@passthrough_domains) { s{^([\d+|\w+](.*))}{\Q$1\E} };
foreach (@passthrough_domains) { s{(\*)(.*)}{\(\.\*\)\Q$2\E} };
foreach (@passthrough_domains) { s{([^/])$}{$1\$} };

my $allow_passthrough_domains = join('|', @passthrough_domains) if (@passthrough_domains ne '0');

if (defined($allow_passthrough_domains)) {
    Readonly::Scalar our $ALLOWED_PASSTHROUGH_DOMAINS => qr/ ^(?: $allow_passthrough_domains ) /xo; # eXtended pattern, compile Once
} else {
    Readonly::Scalar our $ALLOWED_PASSTHROUGH_DOMAINS => '';
}


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


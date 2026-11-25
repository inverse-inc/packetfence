package pf::web::release_form;

=head1 NAME

pf::web::release_form - Values of the web release forms of the switches

=head1 DESCRIPTION

The web release forms (getAcceptForm of the switches) are HTML (and
JavaScript) built from the parameters that the network equipment sent to the
external portal. These functions format these values for the place they are
inserted in.

=cut

use strict;
use warnings;
use HTML::Entities qw(encode_entities);
use JSON::MaybeXS;
use URI;
use URI::Escape::XS qw(uri_escape);
use pf::log;

use base qw(Exporter);
our @EXPORT_OK = qw(html_attr js_string http_url url_host url_port url_param);

my $JSON = JSON::MaybeXS->new(allow_nonref => 1, ascii => 1);

=head2 html_attr

A value escaped for an HTML attribute (or HTML text)

=cut

sub html_attr {
    my ($value) = @_;
    return encode_entities($value // '', q{<>&"'});
}

=head2 js_string

A JavaScript string literal (with its quotes) of a value, that can be
inserted in a script element

=cut

sub js_string {
    my ($value) = @_;
    my $string = $JSON->encode(defined($value) ? "$value" : '');
    # don't close the script element
    $string =~ s{</}{<\\/}g;
    return $string;
}

=head2 http_url

The URL if it is an http or https URL with a host, else '' (a form action or a
redirection only uses http or https)

=cut

sub http_url {
    my ($url) = @_;
    return '' if !defined($url) || !length($url);
    my $uri = URI->new($url);
    my $scheme = $uri->scheme // '';
    if (($scheme eq 'http' || $scheme eq 'https') && _is_host($uri->host)) {
        return $uri->as_string;
    }

    get_logger->warn("Ignoring the URL '$url' of the web release form: not an http or https URL");
    return '';
}

=head2 url_host

The host name or IP address if it is one, else ''

=cut

sub url_host {
    my ($host) = @_;
    return '' if !defined($host);
    return $host if _is_host($host);
    return $host if $host =~ /\A\[(.+)\]\z/ && _is_ipv6($1);
    get_logger->warn("Ignoring the host '$host' of the web release form");
    return '';
}

# a host name, an IPv4 address or an IPv6 address (without brackets)
sub _is_host {
    my ($host) = @_;
    return 0 if !defined($host);
    return 1 if $host =~ /\A[A-Za-z0-9](?:[A-Za-z0-9.\-]*[A-Za-z0-9])?\z/;
    return _is_ipv6($host);
}

sub _is_ipv6 {
    my ($host) = @_;
    return ($host =~ /\A[0-9A-Fa-f:.]+\z/ && $host =~ /:.*:/ && $host =~ /[0-9A-Fa-f]/) ? 1 : 0;
}

=head2 url_port

The port if it is a number, else ''

=cut

sub url_port {
    my ($port) = @_;
    return (defined($port) && $port =~ /\A[0-9]{1,5}\z/) ? $port : '';
}

=head2 url_param

A value escaped for a URL query parameter

=cut

sub url_param {
    my ($value) = @_;
    return uri_escape($value // '');
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

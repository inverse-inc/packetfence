package pf::web::util;

=head1 NAME

pf::web::util - captive portal utilities

=cut

=head1 DESCRIPTION

pf::web::util contains helper functions for the captive portal

It is possible to customize the behavior of this module by redefining its subs in pf::web::custom.
See F<pf::web::custom> for details.

=cut

use strict;
use warnings;

use pf::log;
use pf::constants;
use pf::constants::config qw($TIME_MODIFIER_RE $DEADLINE_UNIT);
use pf::config qw(%Config);
use pf::file_paths qw($ssl_configuration_file);
use pf::util;
use pf::config::util;
use pf::web;
use File::Slurp;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
    );
}

=head1 SUBROUTINES

=over

=cut

=item validate_phone_number

Returns phone number in xxxyyyzzzz format if valid undef otherwise.

=cut

sub validate_phone_number {
    my ($phone_number) = @_;
    return unless defined $phone_number;
    # north american regular expression
    if ($phone_number =~ /
        ^(?:\+?(1)[-.\s]?)?   # optional 1 in front with -, ., space or nothing seperator
        \(?([2-9]\d{2})\)?    # captures first 3 digits allows optional parenthesis
        [-.\s]?               # separator -, ., space or nothing
        (\d{3})               # captures 3 digits
        [-.\s]?               # separator -, ., space or nothing
        (\d{4})$              # captures last 4 digits
        /x) {
        return "$1$2$3$4" if defined($1);
        return "$2$3$4";
    }
    # rest of world regular expression
    if ($phone_number =~ /
        ^\+?\s?              # optional + on front with optional space
        ((?:[0-9]\s?){6,14}   # between 6 and 14 groups of digits seperated by spaces or not
        [0-9])$              # end with a digit
        /x) {
        # trim spaces
        my $return = $1;
        $return =~ s/\s+//g;
        return $return;
    }
    return;
}

=item is_creditcardexpiration_valid

Return 1 if string provided is a valid credit card expiration date, 0 otherwise.

=cut

sub is_creditcardexpiration_valid {
    my ( $credit_card_expiration ) = @_;

    $credit_card_expiration =~ s{/}{};  # We remove potential slash separating character

    if ( $credit_card_expiration =~ /
            ^[0-9]{4}   # The expiration date is made of 4 digits
            $/x
    ) {
        return 1;
    }
    return 0;
}

=item is_credidcardnumber_valid

Return 1 if string provided is a valid credit card number, 0 otherwise.

=cut

sub is_creditcardnumber_valid {
    my ( $credit_card_number ) = @_;

    if ( $credit_card_number =~ / (?:
            4[0-9]{12}(?:[0-9]{3})?|            # Visa
            5[1-5][0-9]{14}|                    # MasterCard
            3[47][0-9]{13}|                     # American Express
            6(?:011|5[0-9][0-9])[0-9]{12}|      # Discover
            3(?:0[0-5]|[68][0-9])[0-9]{11}|     # Diners Club
            (?:2131|1800|35\d{3})\d{11})        # JCB
            $/x
    ) {
        return 1;
    }
    return 0;
}

=item is_creditcardverification_valid

Return 1 if string provided is a valid credit card verification number, 0 otherwise.

=cut

sub is_creditcardverification_valid {
    my ( $credit_card_verification ) = @_;

    if ( $credit_card_verification =~ /
            ^[0-9]{3,4}     # There 3 or 4 digits
            $/x
     ) {
        return 1;
    }
    return 0;
}

=item is_email_valid

Returns 1 if string provided is a valid email address, 0 otherwise.

=cut

sub is_email_valid {
    my ($email) = @_;
    if ($email =~ /
        ^[A-z0-9_.-]+@      # A-Z, a-z, 0-9, _, ., - then @
        [A-z0-9_-]+         # at least one char after @, maybe more
        (\.[A-z0-9_-]+)*\.  # optional unlimited number of sub domains
        [A-z]{2,6}$         # valid top level domain (from 2 to 6 char)
        /x) {
        return 1;
    }
    return 0;
}

=item is_name_valid

Return 1 if string provided is a valid name, 0 otherwise

=cut

sub is_name_valid {
    my ( $name ) = @_;
    if ( $name =~ /
            \w              # only letters are accepted
            /x
    ) {
        return 1;
    }
    return 0;
}

=item get_translated_time_hash

Returns an hashref that holds time values.
 key => short time format (ex: 1h or 1d)
 value => translated long time format. ex: 1 hour (en) 1 heure (fr) or 1 day (en) 1 jour (fr)

=cut

sub get_translated_time_array {
    my ($to_translate, $locale) = @_;

    my @times;
    foreach my $key (@{$to_translate}) {
        my ($unit, $unit_plural, $value) = get_translatable_time($key);
        my $strfmt = $value . " " . ni18n($unit, $unit_plural, $value);

        if ($key =~ /^\d+$TIME_MODIFIER_RE$DEADLINE_UNIT([-+])(\d+$TIME_MODIFIER_RE)$/) {
            ($unit, $unit_plural, $value) = get_translatable_time($2);
            if ($value > 0) {
                $strfmt .= sprintf(" (%s %i %s)", $1, $value, ni18n($unit, $unit_plural, $value));
            }
        }

        # we normalize time so we can present the hash in a sorted fashion
        my $unix_timestamp = normalize_time($key);
        push @times, [$unix_timestamp, $key, $strfmt];
    }

    return \@times;
}

=item

retreive packetfence cookie

=cut

sub getcookie {
    my ($cookies) =@_;
    my $logger = get_logger();
    my $cleaned_cookies = '';
    if ( defined($cookies) ) {
        foreach (split(';', $cookies)) {
            if (/([^,; ]+)=([^,; ]+)/) {
                if ($1 eq 'packetfence'){
                    $cleaned_cookies .= $2;
                }
            }
        }
        if ($cleaned_cookies ne '') {
            return $cleaned_cookies;
        }
    }
    else {
        return $FALSE;
    }
}

=item build_captive_portal_detection_mechanisms_regex

Build a regex that detects if the request is a captive portal detection mechanism request.

Such mechanisms are used by end-points to detect the presence of captive portal and then prompt the end-user accordingly.

Using configuration values from 'captive_portal.detection_mecanism_urls'.

=cut

sub build_captive_portal_detection_mechanisms_regex {
    my @captive_portal_detection_mechanism_urls = @{ $Config{'captive_portal'}{'detection_mecanism_urls'} };

    foreach ( @captive_portal_detection_mechanism_urls ) { s{([^/])$}{$1\$} };

    my $captive_portal_detection_mechanism_urls = join( '|', @captive_portal_detection_mechanism_urls ) if ( @captive_portal_detection_mechanism_urls ne '0' );
    if ( defined($captive_portal_detection_mechanism_urls) ) {
        return qr/ ^(?: $captive_portal_detection_mechanism_urls ) /x; # eXtended pattern
    } else {
        return '';
    }
}

=item is_certificate_self_signed

Check if configured SSL certificate is self-signed

=cut

sub is_certificate_self_signed {
    my $logger = get_logger();

    unless ( -e $ssl_configuration_file ) {
        $logger->warn("Unable to read the SSL certificate file '$ssl_configuration_file', assuming self-signed");
        return $TRUE;
    }

    my $httpd_ssl_conf = read_file($ssl_configuration_file);
    my $httpd_ssl_crt;

    if ( $httpd_ssl_conf =~ /SSLCertificateFile\s*(.*)\s*/ ) {
        $httpd_ssl_crt = $1;
    } else {
        $logger->warn("Cannot find the SSL certificate in configuration from file '$ssl_configuration_file', assuming self-signed");
        return $TRUE;
    }

    my $self_signed;
    eval {
        if ( cert_is_self_signed($httpd_ssl_crt) ) {
            $logger->debug("SSL certificate '$httpd_ssl_crt' from file '$ssl_configuration_file' is self-signed");
            $self_signed = $TRUE;
        } else {
            $logger->debug("SSL certificate '$httpd_ssl_crt' from file '$ssl_configuration_file' is not self-signed");
            $self_signed = $FALSE;
        }
    };
    if ($@) {
        $logger->warn("Unable to open SSL certificate '$httpd_ssl_crt' from file '$ssl_configuration_file', assuming self-signed");
        return $TRUE;
    }

    return $self_signed;
}

=head2 generate_doc_url

Generate the URL to a section of documentation

=cut

sub generate_doc_url {
    my ($section, $guide) = @_;
    $guide //= "Installation_Guide";
    return "/static/doc/PacketFence_$guide.html#$section"
}

=head2 generate_doc_url

Generate the HTML link to a section of documentation

=cut

sub generate_doc_link {
    my ($section, $guide) = @_;
    return '<a target="_blank" href="' . generate_doc_url($section, $guide) . '"><i class="icon-question-circle-o"></i></a>';
}

=back

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

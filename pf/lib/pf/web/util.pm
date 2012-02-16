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

use Locale::gettext;
use POSIX;

use pf::config;
use pf::util;
use pf::web;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw();
}

=head1 SUBROUTINES

=over

=cut

=item validate_phone_number

Returns phone number in xxxyyyzzzz format if valid undef otherwise.

=cut
sub validate_phone_number {
    my ($phone_number) = @_;

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
sub get_translated_time_hash {
    my ($to_translate, $locale) = @_;
    setlocale( LC_MESSAGES, $locale );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    my %time;
    foreach my $keys (@{$to_translate}) {
        my ($unit, $unit_plural, $value) = get_translatable_time($keys);
        
        # we normalize time so we can present the hash in a sorted fashion
        my $unix_timestamp = normalize_time($keys);

        $time{$unix_timestamp} = $value . " " . ni18n($unit, $unit_plural, $value);
    }
    return \%time;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010-2011 Inverse inc.

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

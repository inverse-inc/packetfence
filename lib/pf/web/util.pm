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

use pf::config;
use pf::util;
use pf::web;
use Apache::Session::Generate::MD5;
use Apache::Session::Flex;
use Cache::Memcached;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        get_memcached
        get_memcached_conf
        set_memcached
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

sub get_translated_time_hash {
    my ($to_translate, $locale) = @_;

    my %time;
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

        $time{$unix_timestamp} = [$key, $strfmt];
    }
    return \%time;
}

=item get_memcached_conf

Return memcached server list

=cut

sub get_memcached_conf {
    my @serv = ();
    for my $x ( split( ",", $Config{'general'}{'memcached'})) {
        $x =~ s/^\s+//;
        $x =~ s/\s+$//;
        push( @serv, $x );
    }
    return \@serv;
}

=item get_memcached_connection

get memcached object

=cut

sub get_memcached_connection {
    my ( $mc ) = @_;
    my $memd;
    $memd = Cache::Memcached->new(
        servers => $mc,
        debug => 0,
        compress_threshold => 10_000,
    ) unless defined $memd;
    return $memd;
}

=item get_memcached

get information stored in memcached

=cut

sub get_memcached {
    my ( $key, $mc ) = @_;
    my $memd;
    $memd = Cache::Memcached->new(
        servers => $mc,
        debug => 0,
        compress_threshold => 10_000,
    ) unless defined $memd;
    return $memd->get($key);
}

=item set_memcached

set information into memcached

=cut

sub set_memcached {
    my ( $key, $value, $exptime, $mc ) = @_;
    my $memd;
    $memd = Cache::Memcached->new(
        servers => $mc,
        debug => 0,
        compress_threshold => 10_000,
    ) unless defined $memd;

    #limit expiration time to 6000
    $exptime = $exptime || 6_000;
    if ( $exptime > 6_000 ) {
        $exptime = 6_000;
    }

    return $memd->set( $key, $value, $exptime );
}

=item

get information stored in memcached

=cut

sub del_memcached {
    my ( $key, $mc ) = @_;
    my $memd;
    $memd = Cache::Memcached->new(
        servers => $mc,
        debug => 0,
        compress_threshold => 10_000,
    ) unless defined $memd;
    $memd->delete($key);
}

=item

generate or retreive an apache session

=cut

sub session {
    my ($session, $id, $idlength) = @_;
    if (!defined($idlength)) {
        $idlength = 32;
    }
    eval {
        tie %{$session}, 'Apache::Session::Flex', $id, {
                          Store => 'Memcached',
                          Lock => 'Null',
                          Generate => 'MD5',
                          IDLength => $idlength,
                          Serialize => 'Storable',
                          Servers => get_memcached_conf(),
                          };
    } or session($session, undef);

    return $session;
}

=item

retreive packetfence cookie

=cut

sub getcookie {
    my ($cookies) =@_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
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

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

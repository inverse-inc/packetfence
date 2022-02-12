package pf::constants::eap_type;
=head1 NAME

pf::constants::eap_type add documentation

=cut

=head1 DESCRIPTION

Define all EAP types

=cut

use strict;
use warnings;
use base qw(Exporter);
use Readonly;

our @EXPORT_OK = qw(
    $NONE $IDENTITY $NOTIFICATION $NAK $EAP_MD5 $MD5 $ONE_TIME_PASSWORD $OTP $GENERIC_TOKEN_CARD
    $EAP_GTC $GTC $RSA_PUBLIC_KEY $DSS_UNILATERAL $KEA $KEA_VALIDATE $EAP_TLS $TLS $DEFENDER_TOKEN
    $RSA_SECURID_EAP $ARCOT_SYSTEMS_EAP $CISCO_LEAP $LEAP $NOKIA_IP_SMART_CARD $SIM $EAP_SIM $SRP_SHA1
    $EAP_TTLS $TTLS $REMOTE_ACCESS_SERVICE $AKA $EAP_AKA $EAP_3COM_WIRELESS $PEAP
    $MICROSOFT_MS_CHAPV2 $MSCHAPV2 $EQP_MSCHAPV2 $MAKE $CRYPTOCARD $CISCO_MS_CHAPv2
    $DYNAMID $ROB_EAP $SECURID_EAP $MS_AUTHENTICATION_TLV $SENTRINET $AACTIONEC_WIRELESS
    $COGENT_BIOMETRIC_EAP $AIRFORTRESS_EAP $HTTP_DIGEST $TNC $SECURISUITE_EAP
    $DEVICECONNECT_EAP $SPEKE $MOBAC $FAST $ZONELABS $LINK $PAX $PSK
    $SAKE $IKEV2 $AKA2 $GPSK $PWD $EKEV1 %RADIUS_EAP_TYPE_2_VALUES
    %RADIUS_EAP_VALUES_2_TYPE
);

# Eap_type types
Readonly::Scalar our $NONE => 0;
Readonly::Scalar our $IDENTITY => 1;
Readonly::Scalar our $NOTIFICATION => 2;
Readonly::Scalar our $NAK => 3;
Readonly::Scalar our $EAP_MD5 => 4;
Readonly::Scalar our $MD5 => 4;
Readonly::Scalar our $ONE_TIME_PASSWORD => 5;
Readonly::Scalar our $OTP => 5;
Readonly::Scalar our $GENERIC_TOKEN_CARD => 6;
Readonly::Scalar our $EAP_GTC => 6;
Readonly::Scalar our $GTC => 6;
Readonly::Scalar our $RSA_PUBLIC_KEY => 9;
Readonly::Scalar our $DSS_UNILATERAL => 10;
Readonly::Scalar our $KEA => 11;
Readonly::Scalar our $KEA_VALIDATE => 12;
Readonly::Scalar our $EAP_TLS => 13;
Readonly::Scalar our $TLS => 13;
Readonly::Scalar our $DEFENDER_TOKEN => 14;
Readonly::Scalar our $RSA_SECURID_EAP => 15;
Readonly::Scalar our $ARCOT_SYSTEMS_EAP => 16;
Readonly::Scalar our $CISCO_LEAP => 17;
Readonly::Scalar our $LEAP => 17;
Readonly::Scalar our $NOKIA_IP_SMART_CARD => 18;
Readonly::Scalar our $SIM => 18;
Readonly::Scalar our $EAP_SIM => 18;
Readonly::Scalar our $SRP_SHA1 => 19;
Readonly::Scalar our $EAP_TTLS => 21;
Readonly::Scalar our $TTLS => 21;
Readonly::Scalar our $REMOTE_ACCESS_SERVICE => 22;
Readonly::Scalar our $AKA => 23;
Readonly::Scalar our $EAP_AKA => 23;
Readonly::Scalar our $EAP_3COM_WIRELESS => 24;
Readonly::Scalar our $PEAP => 25;
Readonly::Scalar our $MICROSOFT_MS_CHAPV2 => 26;
Readonly::Scalar our $MSCHAPV2 => 26;
Readonly::Scalar our $EAP_MSCHAPV2 => 26;
Readonly::Scalar our $MAKE => 27;
Readonly::Scalar our $CRYPTOCARD => 28;
Readonly::Scalar our $CISCO_MS_CHAPv2 => 29;
Readonly::Scalar our $DYNAMID => 30;
Readonly::Scalar our $ROB_EAP => 31;
Readonly::Scalar our $SECURID_EAP => 32;
Readonly::Scalar our $MS_AUTHENTICATION_TLV => 33;
Readonly::Scalar our $SENTRINET => 34;
Readonly::Scalar our $AACTIONEC_WIRELESS => 35;
Readonly::Scalar our $COGENT_BIOMETRIC_EAP => 36;
Readonly::Scalar our $AIRFORTRESS_EAP => 37;
Readonly::Scalar our $HTTP_DIGEST => 38;
Readonly::Scalar our $TNC => 38;
Readonly::Scalar our $SECURISUITE_EAP => 39;
Readonly::Scalar our $DEVICECONNECT_EAP => 40;
Readonly::Scalar our $SPEKE => 41;
Readonly::Scalar our $MOBAC => 42;
Readonly::Scalar our $FAST => 43;
Readonly::Scalar our $ZONELABS => 44;
Readonly::Scalar our $LINK => 45;
Readonly::Scalar our $PAX => 46;
Readonly::Scalar our $PSK => 47;
Readonly::Scalar our $SAKE => 48;
Readonly::Scalar our $EAP_IKEV2 => 49;
Readonly::Scalar our $IKEV2 => 49;
Readonly::Scalar our $AKA2 => 50;
Readonly::Scalar our $GPSK => 51;
Readonly::Scalar our $PWD => 52;
Readonly::Scalar our $EKEV1 => 53;

#This was auto generated from the following command
# egrep ^VALUE /usr/share/freeradius/dictionary.freeradius.internal  | grep "EAP-Type" | awk 'BEGIN{print "our %RADIUS_EAP_TYPE_2_VALUES = ("} {print "    \"" $3 "\" => "  $4 "," } END { print ");" }'

our %RADIUS_EAP_TYPE_2_VALUES = (
    "None" => 0,
    "Identity" => 1,
    "Notification" => 2,
    "NAK" => 3,
    "MD5-Challenge" => 4,
    "EAP-MD5" => 4,
    "MD5" => 4,
    "One-Time-Password" => 5,
    "OTP" => 5,
    "Generic-Token-Card" => 6,
    "EAP-GTC" => 6,
    "GTC" => 6,
    "RSA-Public-Key" => 9,
    "DSS-Unilateral" => 10,
    "KEA" => 11,
    "KEA-Validate" => 12,
    "EAP-TLS" => 13,
    "TLS" => 13,
    "Defender-Token" => 14,
    "RSA-SecurID-EAP" => 15,
    "Arcot-Systems-EAP" => 16,
    "Cisco-LEAP" => 17,
    "LEAP" => 17,
    "Nokia-IP-Smart-Card" => 18,
    "EAP-SIM" => 18,
    "SIM" => 18,
    "SRP-SHA1" => 19,
    "EAP-TTLS" => 21,
    "TTLS" => 21,
    "Remote-Access-Service" => 22,
    "EAP-AKA" => 23,
    "AKA" => 23,
    "3Com-Wireless" => 24,
    "PEAP" => 25,
    "Microsoft-MS-CHAPv2" => 26,
    "MAKE" => 27,
    "CRYPTOCard" => 28,
    "Cisco-MS-CHAPv2" => 29,
    "DynamID" => 30,
    "Rob-EAP" => 31,
    "SecurID-EAP" => 32,
    "MS-Authentication-TLV" => 33,
    "SentriNET" => 34,
    "Actiontec-Wireless" => 35,
    "Cogent-Biomentric-EAP" => 36,
    "AirFortress-EAP" => 37,
    "HTTP-Digest" => 38,
    "TNC" => 38,
    "SecuriSuite-EAP" => 39,
    "DeviceConnect-EAP" => 40,
    "SPEKE" => 41,
    "MOBAC" => 42,
    "EAP-FAST" => 43,
    "FAST" => 43,
    "Zonelabs" => 44,
    "Link" => 45,
    "PAX" => 46,
    "PSK" => 47,
    "SAKE" => 48,
    "EAP-IKEv2" => 49,
    "IKEv2" => 49,
    "AKA2" => 50,
    "GPSK" => 51,
    "PWD" => 52,
    "EKEv1" => 53,
    "EAP-MSCHAPv2" => 26,
    "MSCHAPv2" => 26,
);

our %RADIUS_EAP_VALUES_2_TYPE = map { $RADIUS_EAP_TYPE_2_VALUES{$_} => $_ } keys %RADIUS_EAP_TYPE_2_VALUES;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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


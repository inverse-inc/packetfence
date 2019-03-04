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
    $NONE $IDENTITY $NOTIFICATION $NAK $MD5_CHALLENGE $ONE_TIME_PASSWORD $GENERIC_TOKEN_CARD
    $RSA_PUBLIC_KEY $DSS_UNILATERAL $KEA $KEA_VALIDATE $EAP_TLS $DEFENDER_TOKEN
    $RSA_SECURID_EAP $ARCOT_SYSTEMS_EAP $CISCO_LEAP $NOKIA_IP_SMART_CARD $SIM $SRP_SHA1
    $EAP_TTLS $REMOTE_ACCESS_SERVICE $AKA $EAP_3COM_WIRELESS $PEAP $MS_EAP_AUTHENTICATION
    $MICROSOFT_MS_CHAPV2 $MS_CHAP_V2 $MAKE $CRYPTOCARD $EAP_MSCHAP_V2 $CISCO_MS_CHAPv2
    $DYNAMID $ROB_EAP $SECURID_EAP $MS_AUTHENTICATION_TLV $SENTRINET $EAP_AACTIONEC_WIRELESS
    $COGENT_BIOMETRIC_EAP $AIRFORTRESS_EAP $EAP_HTTP_DIGEST $SECURISUITE_EAP
    $DEVICECONNECT_EAP $EAP_SPEKE $EAP_MOBAC $EAP_FAST $ZONELABS $EAP_LINK $EAP_PAX $EAP_PSK
    $EAP_SAKE $EAP_IKEV2 $EAP_AKA2 $EAP_GPSK $EAP_PWD $EAP_EVEV1 %RADIUS_EAP_TYPE_2_VALUES
    %RADIUS_EAP_VALUES_2_TYPE
);

# Eap_type types
Readonly::Scalar our $NONE => 0;
Readonly::Scalar our $IDENTITY => 1;
Readonly::Scalar our $NOTIFICATION => 2;
Readonly::Scalar our $NAK => 3;
Readonly::Scalar our $MD5_CHALLENGE => 4;
Readonly::Scalar our $ONE_TIME_PASSWORD => 5;
Readonly::Scalar our $GENERIC_TOKEN_CARD => 6;
Readonly::Scalar our $RSA_PUBLIC_KEY => 9;
Readonly::Scalar our $DSS_UNILATERAL => 10;
Readonly::Scalar our $KEA => 11;
Readonly::Scalar our $KEA_VALIDATE => 12;
Readonly::Scalar our $EAP_TLS => 13;
Readonly::Scalar our $DEFENDER_TOKEN => 14;
Readonly::Scalar our $RSA_SECURID_EAP => 15;
Readonly::Scalar our $ARCOT_SYSTEMS_EAP => 16;
Readonly::Scalar our $CISCO_LEAP => 17;
Readonly::Scalar our $NOKIA_IP_SMART_CARD => 18;
Readonly::Scalar our $SIM => 18;
Readonly::Scalar our $SRP_SHA1 => 19;
Readonly::Scalar our $EAP_TTLS => 21;
Readonly::Scalar our $REMOTE_ACCESS_SERVICE => 22;
Readonly::Scalar our $AKA => 23;
Readonly::Scalar our $EAP_3COM_WIRELESS => 24;
Readonly::Scalar our $PEAP => 25;
Readonly::Scalar our $MS_EAP_AUTHENTICATION => 26;
Readonly::Scalar our $MICROSOFT_MS_CHAPV2 => 26;
Readonly::Scalar our $MS_CHAP_V2 => 26;
Readonly::Scalar our $MAKE => 27;
Readonly::Scalar our $CRYPTOCARD => 28;
Readonly::Scalar our $EAP_MSCHAP_V2 => 29;
Readonly::Scalar our $CISCO_MS_CHAPv2 => 29;
Readonly::Scalar our $DYNAMID => 30;
Readonly::Scalar our $ROB_EAP => 31;
Readonly::Scalar our $SECURID_EAP => 32;
Readonly::Scalar our $MS_AUTHENTICATION_TLV => 33;
Readonly::Scalar our $SENTRINET => 34;
Readonly::Scalar our $EAP_AACTIONEC_WIRELESS => 35;
Readonly::Scalar our $COGENT_BIOMETRIC_EAP => 36;
Readonly::Scalar our $AIRFORTRESS_EAP => 37;
Readonly::Scalar our $EAP_HTTP_DIGEST => 38;
Readonly::Scalar our $SECURISUITE_EAP => 39;
Readonly::Scalar our $DEVICECONNECT_EAP => 40;
Readonly::Scalar our $EAP_SPEKE => 41;
Readonly::Scalar our $EAP_MOBAC => 42;
Readonly::Scalar our $EAP_FAST => 43;
Readonly::Scalar our $ZONELABS => 44;
Readonly::Scalar our $EAP_LINK => 45;
Readonly::Scalar our $EAP_PAX => 46;
Readonly::Scalar our $EAP_PSK => 47;
Readonly::Scalar our $EAP_SAKE => 48;
Readonly::Scalar our $EAP_IKEV2 => 49;
Readonly::Scalar our $EAP_AKA2 => 50;
Readonly::Scalar our $EAP_GPSK => 51;
Readonly::Scalar our $EAP_PWD => 52;
Readonly::Scalar our $EAP_EVEV1 => 53;

#This was auto generated from the following command
# egrep ^ATTRIBUTE /usr/share/freeradius/dictionary.freeradius.internal  | grep EAP-Type- | awk 'BEGIN{print "our %RADIUS_EAP_TYPE_2_VALUES = ("} {print "    \"" $2 "\" => "  $3 - 1280 "," } END { print ");" }' | perl -p -e's/EAP-Type-//'

our %RADIUS_EAP_TYPE_2_VALUES = (
    "Base" => 0,
    "VALUE" => 0,
    "None" => 0,
    "Identity" => 1,
    "Notification" => 2,
    "NAK" => 3,
    "MD5-Challenge" => 4,
    "One-Time-Password" => 5,
    "Generic-Token-Card" => 6,
    "RSA-Public-Key" => 9,
    "DSS-Unilateral" => 10,
    "KEA" => 11,
    "KEA-Validate" => 12,
    "EAP-TLS" => 13,
    "Defender-Token" => 14,
    "RSA-SecurID-EAP" => 15,
    "Arcot-Systems-EAP" => 16,
    "Cisco-LEAP" => 17,
    "Nokia-IP-Smart-Card" => 18,
    "SIM" => 18,
    "SRP-SHA1" => 19,
    "EAP-TTLS" => 21,
    "Remote-Access-Service" => 22,
    "AKA" => 23,
    "EAP-3Com-Wireless" => 24,
    "PEAP" => 25,
    "MS-EAP-Authentication" => 26,
    "MAKE" => 27,
    "CRYPTOCard" => 28,
    "EAP-MSCHAP-V2" => 29,
    "DynamID" => 30,
    "Rob-EAP" => 31,
    "SecurID-EAP" => 32,
    "MS-Authentication-TLV" => 33,
    "SentriNET" => 34,
    "EAP-Actiontec-Wireless" => 35,
    "Cogent-Biomentric-EAP" => 36,
    "AirFortress-EAP" => 37,
    "EAP-HTTP-Digest" => 38,
    "SecuriSuite-EAP" => 39,
    "DeviceConnect-EAP" => 40,
    "EAP-SPEKE" => 41,
    "EAP-MOBAC" => 42,
    "EAP-FAST" => 43,
    "Zonelabs" => 44,
    "EAP-Link" => 45,
    "EAP-PAX" => 46,
    "EAP-PSK" => 47,
    "EAP-SAKE" => 48,
    "EAP-IKEv2" => 49,
    "EAP-AKA2" => 50,
    "EAP-GPSK" => 51,
    "EAP-PWD" => 52,
    "EAP-EVEv1" => 53,
    "Microsoft-MS-CHAPv2" => 26,
    "Cisco-MS-CHAPv2" => 29,
    "MS-CHAP-V2" => 26,
);

our %RADIUS_EAP_VALUES_2_TYPE = map { $RADIUS_EAP_TYPE_2_VALUES{$_} => $_ } keys %RADIUS_EAP_TYPE_2_VALUES;

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


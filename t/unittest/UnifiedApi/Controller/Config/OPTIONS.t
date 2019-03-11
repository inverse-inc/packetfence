#!/usr/bin/perl

=head1 NAME

OPTIONS

=head1 DESCRIPTION

unit test for OPTIONS

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 15;

#This test will running last
use Test::Mojo;

#This test will running last
use Test::NoWarnings;
my $t = Test::Mojo->new('pf::UnifiedApi');

my $true = bless( do { \( my $o = 1 ) }, 'JSON::PP::Boolean' );
my $false = bless( do { \( my $o = 0 ) }, 'JSON::PP::Boolean' );

$t->options_ok("/api/v1/config/floating_devices")
  ->status_is(200)
  ->json_is(
    {
        meta => {
            id => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required => $true,
                type     => "string",
                pattern => {
                    message => "Mac Address",
                    regex => "[0-9A-Fa-f][0-9A-Fa-f](:[0-9A-Fa-f][0-9A-Fa-f]){5}",
                },
            },
            ip => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required => $false,
                type     => "string"
            },
            pvid => {
                allowed     => undef,
                default     => undef,
                min_value   => 0,
                placeholder => undef,
                required => $true,
                type     => "integer"
            },
            taggedVlan => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required => $false,
                type     => "string"
            },
            trunkPort => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required => $false,
                type     => "string"
            }
        },
        status => 200
    }
);


$t->options_ok("/api/v1/config/syslog_parsers")
  ->status_is(200)
  ->json_is(
    {
        meta => {
            type => {
                allowed => [
                    {
                        text  => "suricata_md5",
                        value => "suricata_md5"
                    },
                    {
                        text  => "security_onion",
                        value => "security_onion"
                    },
                    {
                        text  => "regex",
                        value => "regex"
                    },
                    {
                        text  => "fortianalyser",
                        value => "fortianalyser"
                    },
                    {
                        text  => "suricata",
                        value => "suricata"
                    },
                    {
                        text  => "dhcp",
                        value => "dhcp"
                    },
                    {
                        text  => "snort",
                        value => "snort"
                    }
                ],
                type => 'string',
            }
        },
        status => 200
    }
);

$t->options_ok("/api/v1/config/syslog_parsers?type=regex")
  ->status_is(200)
  ->json_is(
    {
        meta => {
            id => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required    => $true,
                type        => "string",
                pattern     => {
                    regex   => "^[a-zA-Z0-9][a-zA-Z0-9\._-]*\$",
                    message => "The id is invalid. The id can only contain alphanumeric characters, dashes, period and underscores.",
                },
            },
            lines => {
                allowed => undef,
                default => undef,
                item    => {
                    allowed     => undef,
                    default     => undef,
                    placeholder => undef,
                    required    => $false,
                    type        => "string"
                },
                placeholder => undef,
                required    => $false,
                type        => "array"
            },
            loglines => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required    => $false,
                type        => "string"
            },
            path => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required    => $true,
                type        => "string"
            },
            rules => {
                allowed => undef,
                default => undef,
                item    => {
                    allowed     => undef,
                    default     => undef,
                    placeholder => undef,
                    properties  => {
                        actions => {
                            allowed => undef,
                            default => undef,
                            item    => {
                                allowed     => undef,
                                default     => undef,
                                placeholder => undef,
                                properties  => {
                                    api_method => {
                                        allowed     => [],
                                        default     => undef,
                                        placeholder => undef,
                                        required    => $true,
                                        type        => "string"
                                    },
                                    api_parameters => {
                                        allowed     => undef,
                                        default     => undef,
                                        placeholder => undef,
                                        required    => $true,
                                        type        => "string"
                                    }
                                },
                                required => $false,
                                type     => "object"
                            },
                            placeholder => undef,
                            required    => $false,
                            type        => "array"
                        },
                        ip_mac_translation => {
                            allowed     => undef,
                            default     => undef,
                            placeholder => undef,
                            required    => $false,
                            type        => "string"
                        },
                        last_if_match => {
                            allowed     => undef,
                            default     => undef,
                            placeholder => undef,
                            required    => $false,
                            type        => "string"
                        },
                        name => {
                            allowed     => undef,
                            default     => undef,
                            placeholder => undef,
                            required    => $true,
                            type        => "string"
                        },
                        regex => {
                            allowed     => undef,
                            default     => undef,
                            placeholder => undef,
                            required    => $true,
                            type        => "string"
                        }
                    },
                    required => $false,
                    type     => "object"
                },
                placeholder => undef,
                required    => $false,
                type        => "array"
            },
            status => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required    => $false,
                type        => "string"
            },
            type => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required    => $true,
                type        => "string"
            }
        },
        status => 200
    }
);

$t->options_ok("/api/v1/config/base/general")
  ->status_is(200)
  ->json_is(
    {
        meta => {
            dhcpservers => {
                allowed     => undef,
                default     => undef,
                placeholder => '127.0.0.1',
                required    => $false,
                type        => "string"
            },
            domain => {
                allowed     => undef,
                default     => undef,
                placeholder => 'packetfence.org',
                required    => $false,
                type        => "string"
            },
            hostname => {
                allowed     => undef,
                default     => undef,
                placeholder => 'packetfence',
                required    => $false,
                type        => "string"
            },
            timezone => {
                allowed => [
                    {
                        text => "",
                        value => ""
                    },
                    {
                        text => "Africa/Abidjan",
                        value => "Africa/Abidjan"
                    },
                    {
                        text => "Africa/Accra",
                        value => "Africa/Accra"
                    },
                    {
                        text => "Africa/Algiers",
                        value => "Africa/Algiers"
                    },
                    {
                        text => "Africa/Bissau",
                        value => "Africa/Bissau"
                    },
                    {
                        text => "Africa/Cairo",
                        value => "Africa/Cairo"
                    },
                    {
                        text => "Africa/Casablanca",
                        value => "Africa/Casablanca"
                    },
                    {
                        text => "Africa/Ceuta",
                        value => "Africa/Ceuta"
                    },
                    {
                        text => "Africa/El_Aaiun",
                        value => "Africa/El_Aaiun"
                    },
                    {
                        text => "Africa/Johannesburg",
                        value => "Africa/Johannesburg"
                    },
                    {
                        text => "Africa/Khartoum",
                        value => "Africa/Khartoum"
                    },
                    {
                        text => "Africa/Lagos",
                        value => "Africa/Lagos"
                    },
                    {
                        text => "Africa/Maputo",
                        value => "Africa/Maputo"
                    },
                    {
                        text => "Africa/Monrovia",
                        value => "Africa/Monrovia"
                    },
                    {
                        text => "Africa/Nairobi",
                        value => "Africa/Nairobi"
                    },
                    {
                        text => "Africa/Ndjamena",
                        value => "Africa/Ndjamena"
                    },
                    {
                        text => "Africa/Tripoli",
                        value => "Africa/Tripoli"
                    },
                    {
                        text => "Africa/Tunis",
                        value => "Africa/Tunis"
                    },
                    {
                        text => "Africa/Windhoek",
                        value => "Africa/Windhoek"
                    },
                    {
                        text => "America/Adak",
                        value => "America/Adak"
                    },
                    {
                        text => "America/Anchorage",
                        value => "America/Anchorage"
                    },
                    {
                        text => "America/Araguaina",
                        value => "America/Araguaina"
                    },
                    {
                        text => "America/Argentina/Buenos_Aires",
                        value => "America/Argentina/Buenos_Aires"
                    },
                    {
                        text => "America/Argentina/Catamarca",
                        value => "America/Argentina/Catamarca"
                    },
                    {
                        text => "America/Argentina/Cordoba",
                        value => "America/Argentina/Cordoba"
                    },
                    {
                        text => "America/Argentina/Jujuy",
                        value => "America/Argentina/Jujuy"
                    },
                    {
                        text => "America/Argentina/La_Rioja",
                        value => "America/Argentina/La_Rioja"
                    },
                    {
                        text => "America/Argentina/Mendoza",
                        value => "America/Argentina/Mendoza"
                    },
                    {
                        text => "America/Argentina/Rio_Gallegos",
                        value => "America/Argentina/Rio_Gallegos"
                    },
                    {
                        text => "America/Argentina/Salta",
                        value => "America/Argentina/Salta"
                    },
                    {
                        text => "America/Argentina/San_Juan",
                        value => "America/Argentina/San_Juan"
                    },
                    {
                        text => "America/Argentina/San_Luis",
                        value => "America/Argentina/San_Luis"
                    },
                    {
                        text => "America/Argentina/Tucuman",
                        value => "America/Argentina/Tucuman"
                    },
                    {
                        text => "America/Argentina/Ushuaia",
                        value => "America/Argentina/Ushuaia"
                    },
                    {
                        text => "America/Asuncion",
                        value => "America/Asuncion"
                    },
                    {
                        text => "America/Atikokan",
                        value => "America/Atikokan"
                    },
                    {
                        text => "America/Bahia",
                        value => "America/Bahia"
                    },
                    {
                        text => "America/Bahia_Banderas",
                        value => "America/Bahia_Banderas"
                    },
                    {
                        text => "America/Barbados",
                        value => "America/Barbados"
                    },
                    {
                        text => "America/Belem",
                        value => "America/Belem"
                    },
                    {
                        text => "America/Belize",
                        value => "America/Belize"
                    },
                    {
                        text => "America/Blanc-Sablon",
                        value => "America/Blanc-Sablon"
                    },
                    {
                        text => "America/Boa_Vista",
                        value => "America/Boa_Vista"
                    },
                    {
                        text => "America/Bogota",
                        value => "America/Bogota"
                    },
                    {
                        text => "America/Boise",
                        value => "America/Boise"
                    },
                    {
                        text => "America/Cambridge_Bay",
                        value => "America/Cambridge_Bay"
                    },
                    {
                        text => "America/Campo_Grande",
                        value => "America/Campo_Grande"
                    },
                    {
                        text => "America/Cancun",
                        value => "America/Cancun"
                    },
                    {
                        text => "America/Caracas",
                        value => "America/Caracas"
                    },
                    {
                        text => "America/Cayenne",
                        value => "America/Cayenne"
                    },
                    {
                        text => "America/Chicago",
                        value => "America/Chicago"
                    },
                    {
                        text => "America/Chihuahua",
                        value => "America/Chihuahua"
                    },
                    {
                        text => "America/Costa_Rica",
                        value => "America/Costa_Rica"
                    },
                    {
                        text => "America/Creston",
                        value => "America/Creston"
                    },
                    {
                        text => "America/Cuiaba",
                        value => "America/Cuiaba"
                    },
                    {
                        text => "America/Curacao",
                        value => "America/Curacao"
                    },
                    {
                        text => "America/Danmarkshavn",
                        value => "America/Danmarkshavn"
                    },
                    {
                        text => "America/Dawson",
                        value => "America/Dawson"
                    },
                    {
                        text => "America/Dawson_Creek",
                        value => "America/Dawson_Creek"
                    },
                    {
                        text => "America/Denver",
                        value => "America/Denver"
                    },
                    {
                        text => "America/Detroit",
                        value => "America/Detroit"
                    },
                    {
                        text => "America/Edmonton",
                        value => "America/Edmonton"
                    },
                    {
                        text => "America/Eirunepe",
                        value => "America/Eirunepe"
                    },
                    {
                        text => "America/El_Salvador",
                        value => "America/El_Salvador"
                    },
                    {
                        text => "America/Fort_Nelson",
                        value => "America/Fort_Nelson"
                    },
                    {
                        text => "America/Fortaleza",
                        value => "America/Fortaleza"
                    },
                    {
                        text => "America/Glace_Bay",
                        value => "America/Glace_Bay"
                    },
                    {
                        text => "America/Godthab",
                        value => "America/Godthab"
                    },
                    {
                        text => "America/Goose_Bay",
                        value => "America/Goose_Bay"
                    },
                    {
                        text => "America/Grand_Turk",
                        value => "America/Grand_Turk"
                    },
                    {
                        text => "America/Guatemala",
                        value => "America/Guatemala"
                    },
                    {
                        text => "America/Guayaquil",
                        value => "America/Guayaquil"
                    },
                    {
                        text => "America/Guyana",
                        value => "America/Guyana"
                    },
                    {
                        text => "America/Halifax",
                        value => "America/Halifax"
                    },
                    {
                        text => "America/Havana",
                        value => "America/Havana"
                    },
                    {
                        text => "America/Hermosillo",
                        value => "America/Hermosillo"
                    },
                    {
                        text => "America/Indiana/Indianapolis",
                        value => "America/Indiana/Indianapolis"
                    },
                    {
                        text => "America/Indiana/Knox",
                        value => "America/Indiana/Knox"
                    },
                    {
                        text => "America/Indiana/Marengo",
                        value => "America/Indiana/Marengo"
                    },
                    {
                        text => "America/Indiana/Petersburg",
                        value => "America/Indiana/Petersburg"
                    },
                    {
                        text => "America/Indiana/Tell_City",
                        value => "America/Indiana/Tell_City"
                    },
                    {
                        text => "America/Indiana/Vevay",
                        value => "America/Indiana/Vevay"
                    },
                    {
                        text => "America/Indiana/Vincennes",
                        value => "America/Indiana/Vincennes"
                    },
                    {
                        text => "America/Indiana/Winamac",
                        value => "America/Indiana/Winamac"
                    },
                    {
                        text => "America/Inuvik",
                        value => "America/Inuvik"
                    },
                    {
                        text => "America/Iqaluit",
                        value => "America/Iqaluit"
                    },
                    {
                        text => "America/Jamaica",
                        value => "America/Jamaica"
                    },
                    {
                        text => "America/Juneau",
                        value => "America/Juneau"
                    },
                    {
                        text => "America/Kentucky/Louisville",
                        value => "America/Kentucky/Louisville"
                    },
                    {
                        text => "America/Kentucky/Monticello",
                        value => "America/Kentucky/Monticello"
                    },
                    {
                        text => "America/La_Paz",
                        value => "America/La_Paz"
                    },
                    {
                        text => "America/Lima",
                        value => "America/Lima"
                    },
                    {
                        text => "America/Los_Angeles",
                        value => "America/Los_Angeles"
                    },
                    {
                        text => "America/Maceio",
                        value => "America/Maceio"
                    },
                    {
                        text => "America/Managua",
                        value => "America/Managua"
                    },
                    {
                        text => "America/Manaus",
                        value => "America/Manaus"
                    },
                    {
                        text => "America/Martinique",
                        value => "America/Martinique"
                    },
                    {
                        text => "America/Matamoros",
                        value => "America/Matamoros"
                    },
                    {
                        text => "America/Mazatlan",
                        value => "America/Mazatlan"
                    },
                    {
                        text => "America/Menominee",
                        value => "America/Menominee"
                    },
                    {
                        text => "America/Merida",
                        value => "America/Merida"
                    },
                    {
                        text => "America/Metlakatla",
                        value => "America/Metlakatla"
                    },
                    {
                        text => "America/Mexico_City",
                        value => "America/Mexico_City"
                    },
                    {
                        text => "America/Miquelon",
                        value => "America/Miquelon"
                    },
                    {
                        text => "America/Moncton",
                        value => "America/Moncton"
                    },
                    {
                        text => "America/Monterrey",
                        value => "America/Monterrey"
                    },
                    {
                        text => "America/Montevideo",
                        value => "America/Montevideo"
                    },
                    {
                        text => "America/Nassau",
                        value => "America/Nassau"
                    },
                    {
                        text => "America/New_York",
                        value => "America/New_York"
                    },
                    {
                        text => "America/Nipigon",
                        value => "America/Nipigon"
                    },
                    {
                        text => "America/Nome",
                        value => "America/Nome"
                    },
                    {
                        text => "America/Noronha",
                        value => "America/Noronha"
                    },
                    {
                        text => "America/North_Dakota/Beulah",
                        value => "America/North_Dakota/Beulah"
                    },
                    {
                        text => "America/North_Dakota/Center",
                        value => "America/North_Dakota/Center"
                    },
                    {
                        text => "America/North_Dakota/New_Salem",
                        value => "America/North_Dakota/New_Salem"
                    },
                    {
                        text => "America/Ojinaga",
                        value => "America/Ojinaga"
                    },
                    {
                        text => "America/Panama",
                        value => "America/Panama"
                    },
                    {
                        text => "America/Pangnirtung",
                        value => "America/Pangnirtung"
                    },
                    {
                        text => "America/Paramaribo",
                        value => "America/Paramaribo"
                    },
                    {
                        text => "America/Phoenix",
                        value => "America/Phoenix"
                    },
                    {
                        text => "America/Port-au-Prince",
                        value => "America/Port-au-Prince"
                    },
                    {
                        text => "America/Port_of_Spain",
                        value => "America/Port_of_Spain"
                    },
                    {
                        text => "America/Porto_Velho",
                        value => "America/Porto_Velho"
                    },
                    {
                        text => "America/Puerto_Rico",
                        value => "America/Puerto_Rico"
                    },
                    {
                        text => "America/Punta_Arenas",
                        value => "America/Punta_Arenas"
                    },
                    {
                        text => "America/Rainy_River",
                        value => "America/Rainy_River"
                    },
                    {
                        text => "America/Rankin_Inlet",
                        value => "America/Rankin_Inlet"
                    },
                    {
                        text => "America/Recife",
                        value => "America/Recife"
                    },
                    {
                        text => "America/Regina",
                        value => "America/Regina"
                    },
                    {
                        text => "America/Resolute",
                        value => "America/Resolute"
                    },
                    {
                        text => "America/Rio_Branco",
                        value => "America/Rio_Branco"
                    },
                    {
                        text => "America/Santarem",
                        value => "America/Santarem"
                    },
                    {
                        text => "America/Santiago",
                        value => "America/Santiago"
                    },
                    {
                        text => "America/Santo_Domingo",
                        value => "America/Santo_Domingo"
                    },
                    {
                        text => "America/Sao_Paulo",
                        value => "America/Sao_Paulo"
                    },
                    {
                        text => "America/Scoresbysund",
                        value => "America/Scoresbysund"
                    },
                    {
                        text => "America/Sitka",
                        value => "America/Sitka"
                    },
                    {
                        text => "America/St_Johns",
                        value => "America/St_Johns"
                    },
                    {
                        text => "America/Swift_Current",
                        value => "America/Swift_Current"
                    },
                    {
                        text => "America/Tegucigalpa",
                        value => "America/Tegucigalpa"
                    },
                    {
                        text => "America/Thule",
                        value => "America/Thule"
                    },
                    {
                        text => "America/Thunder_Bay",
                        value => "America/Thunder_Bay"
                    },
                    {
                        text => "America/Tijuana",
                        value => "America/Tijuana"
                    },
                    {
                        text => "America/Toronto",
                        value => "America/Toronto"
                    },
                    {
                        text => "America/Vancouver",
                        value => "America/Vancouver"
                    },
                    {
                        text => "America/Whitehorse",
                        value => "America/Whitehorse"
                    },
                    {
                        text => "America/Winnipeg",
                        value => "America/Winnipeg"
                    },
                    {
                        text => "America/Yakutat",
                        value => "America/Yakutat"
                    },
                    {
                        text => "America/Yellowknife",
                        value => "America/Yellowknife"
                    },
                    {
                        text => "Antarctica/Casey",
                        value => "Antarctica/Casey"
                    },
                    {
                        text => "Antarctica/Davis",
                        value => "Antarctica/Davis"
                    },
                    {
                        text => "Antarctica/DumontDUrville",
                        value => "Antarctica/DumontDUrville"
                    },
                    {
                        text => "Antarctica/Macquarie",
                        value => "Antarctica/Macquarie"
                    },
                    {
                        text => "Antarctica/Mawson",
                        value => "Antarctica/Mawson"
                    },
                    {
                        text => "Antarctica/Palmer",
                        value => "Antarctica/Palmer"
                    },
                    {
                        text => "Antarctica/Rothera",
                        value => "Antarctica/Rothera"
                    },
                    {
                        text => "Antarctica/Syowa",
                        value => "Antarctica/Syowa"
                    },
                    {
                        text => "Antarctica/Troll",
                        value => "Antarctica/Troll"
                    },
                    {
                        text => "Antarctica/Vostok",
                        value => "Antarctica/Vostok"
                    },
                    {
                        text => "Asia/Almaty",
                        value => "Asia/Almaty"
                    },
                    {
                        text => "Asia/Amman",
                        value => "Asia/Amman"
                    },
                    {
                        text => "Asia/Anadyr",
                        value => "Asia/Anadyr"
                    },
                    {
                        text => "Asia/Aqtau",
                        value => "Asia/Aqtau"
                    },
                    {
                        text => "Asia/Aqtobe",
                        value => "Asia/Aqtobe"
                    },
                    {
                        text => "Asia/Ashgabat",
                        value => "Asia/Ashgabat"
                    },
                    {
                        text => "Asia/Atyrau",
                        value => "Asia/Atyrau"
                    },
                    {
                        text => "Asia/Baghdad",
                        value => "Asia/Baghdad"
                    },
                    {
                        text => "Asia/Baku",
                        value => "Asia/Baku"
                    },
                    {
                        text => "Asia/Bangkok",
                        value => "Asia/Bangkok"
                    },
                    {
                        text => "Asia/Barnaul",
                        value => "Asia/Barnaul"
                    },
                    {
                        text => "Asia/Beirut",
                        value => "Asia/Beirut"
                    },
                    {
                        text => "Asia/Bishkek",
                        value => "Asia/Bishkek"
                    },
                    {
                        text => "Asia/Brunei",
                        value => "Asia/Brunei"
                    },
                    {
                        text => "Asia/Chita",
                        value => "Asia/Chita"
                    },
                    {
                        text => "Asia/Choibalsan",
                        value => "Asia/Choibalsan"
                    },
                    {
                        text => "Asia/Colombo",
                        value => "Asia/Colombo"
                    },
                    {
                        text => "Asia/Damascus",
                        value => "Asia/Damascus"
                    },
                    {
                        text => "Asia/Dhaka",
                        value => "Asia/Dhaka"
                    },
                    {
                        text => "Asia/Dili",
                        value => "Asia/Dili"
                    },
                    {
                        text => "Asia/Dubai",
                        value => "Asia/Dubai"
                    },
                    {
                        text => "Asia/Dushanbe",
                        value => "Asia/Dushanbe"
                    },
                    {
                        text => "Asia/Famagusta",
                        value => "Asia/Famagusta"
                    },
                    {
                        text => "Asia/Gaza",
                        value => "Asia/Gaza"
                    },
                    {
                        text => "Asia/Hebron",
                        value => "Asia/Hebron"
                    },
                    {
                        text => "Asia/Ho_Chi_Minh",
                        value => "Asia/Ho_Chi_Minh"
                    },
                    {
                        text => "Asia/Hong_Kong",
                        value => "Asia/Hong_Kong"
                    },
                    {
                        text => "Asia/Hovd",
                        value => "Asia/Hovd"
                    },
                    {
                        text => "Asia/Irkutsk",
                        value => "Asia/Irkutsk"
                    },
                    {
                        text => "Asia/Jakarta",
                        value => "Asia/Jakarta"
                    },
                    {
                        text => "Asia/Jayapura",
                        value => "Asia/Jayapura"
                    },
                    {
                        text => "Asia/Jerusalem",
                        value => "Asia/Jerusalem"
                    },
                    {
                        text => "Asia/Kabul",
                        value => "Asia/Kabul"
                    },
                    {
                        text => "Asia/Kamchatka",
                        value => "Asia/Kamchatka"
                    },
                    {
                        text => "Asia/Karachi",
                        value => "Asia/Karachi"
                    },
                    {
                        text => "Asia/Kathmandu",
                        value => "Asia/Kathmandu"
                    },
                    {
                        text => "Asia/Khandyga",
                        value => "Asia/Khandyga"
                    },
                    {
                        text => "Asia/Kolkata",
                        value => "Asia/Kolkata"
                    },
                    {
                        text => "Asia/Krasnoyarsk",
                        value => "Asia/Krasnoyarsk"
                    },
                    {
                        text => "Asia/Kuala_Lumpur",
                        value => "Asia/Kuala_Lumpur"
                    },
                    {
                        text => "Asia/Kuching",
                        value => "Asia/Kuching"
                    },
                    {
                        text => "Asia/Macau",
                        value => "Asia/Macau"
                    },
                    {
                        text => "Asia/Magadan",
                        value => "Asia/Magadan"
                    },
                    {
                        text => "Asia/Makassar",
                        value => "Asia/Makassar"
                    },
                    {
                        text => "Asia/Manila",
                        value => "Asia/Manila"
                    },
                    {
                        text => "Asia/Nicosia",
                        value => "Asia/Nicosia"
                    },
                    {
                        text => "Asia/Novokuznetsk",
                        value => "Asia/Novokuznetsk"
                    },
                    {
                        text => "Asia/Novosibirsk",
                        value => "Asia/Novosibirsk"
                    },
                    {
                        text => "Asia/Omsk",
                        value => "Asia/Omsk"
                    },
                    {
                        text => "Asia/Oral",
                        value => "Asia/Oral"
                    },
                    {
                        text => "Asia/Pontianak",
                        value => "Asia/Pontianak"
                    },
                    {
                        text => "Asia/Pyongyang",
                        value => "Asia/Pyongyang"
                    },
                    {
                        text => "Asia/Qatar",
                        value => "Asia/Qatar"
                    },
                    {
                        text => "Asia/Qyzylorda",
                        value => "Asia/Qyzylorda"
                    },
                    {
                        text => "Asia/Riyadh",
                        value => "Asia/Riyadh"
                    },
                    {
                        text => "Asia/Sakhalin",
                        value => "Asia/Sakhalin"
                    },
                    {
                        text => "Asia/Samarkand",
                        value => "Asia/Samarkand"
                    },
                    {
                        text => "Asia/Seoul",
                        value => "Asia/Seoul"
                    },
                    {
                        text => "Asia/Shanghai",
                        value => "Asia/Shanghai"
                    },
                    {
                        text => "Asia/Singapore",
                        value => "Asia/Singapore"
                    },
                    {
                        text => "Asia/Srednekolymsk",
                        value => "Asia/Srednekolymsk"
                    },
                    {
                        text => "Asia/Taipei",
                        value => "Asia/Taipei"
                    },
                    {
                        text => "Asia/Tashkent",
                        value => "Asia/Tashkent"
                    },
                    {
                        text => "Asia/Tbilisi",
                        value => "Asia/Tbilisi"
                    },
                    {
                        text => "Asia/Tehran",
                        value => "Asia/Tehran"
                    },
                    {
                        text => "Asia/Thimphu",
                        value => "Asia/Thimphu"
                    },
                    {
                        text => "Asia/Tokyo",
                        value => "Asia/Tokyo"
                    },
                    {
                        text => "Asia/Tomsk",
                        value => "Asia/Tomsk"
                    },
                    {
                        text => "Asia/Ulaanbaatar",
                        value => "Asia/Ulaanbaatar"
                    },
                    {
                        text => "Asia/Urumqi",
                        value => "Asia/Urumqi"
                    },
                    {
                        text => "Asia/Ust-Nera",
                        value => "Asia/Ust-Nera"
                    },
                    {
                        text => "Asia/Vladivostok",
                        value => "Asia/Vladivostok"
                    },
                    {
                        text => "Asia/Yakutsk",
                        value => "Asia/Yakutsk"
                    },
                    {
                        text => "Asia/Yangon",
                        value => "Asia/Yangon"
                    },
                    {
                        text => "Asia/Yekaterinburg",
                        value => "Asia/Yekaterinburg"
                    },
                    {
                        text => "Asia/Yerevan",
                        value => "Asia/Yerevan"
                    },
                    {
                        text => "Atlantic/Azores",
                        value => "Atlantic/Azores"
                    },
                    {
                        text => "Atlantic/Bermuda",
                        value => "Atlantic/Bermuda"
                    },
                    {
                        text => "Atlantic/Canary",
                        value => "Atlantic/Canary"
                    },
                    {
                        text => "Atlantic/Cape_Verde",
                        value => "Atlantic/Cape_Verde"
                    },
                    {
                        text => "Atlantic/Faroe",
                        value => "Atlantic/Faroe"
                    },
                    {
                        text => "Atlantic/Madeira",
                        value => "Atlantic/Madeira"
                    },
                    {
                        text => "Atlantic/Reykjavik",
                        value => "Atlantic/Reykjavik"
                    },
                    {
                        text => "Atlantic/South_Georgia",
                        value => "Atlantic/South_Georgia"
                    },
                    {
                        text => "Atlantic/Stanley",
                        value => "Atlantic/Stanley"
                    },
                    {
                        text => "Australia/Adelaide",
                        value => "Australia/Adelaide"
                    },
                    {
                        text => "Australia/Brisbane",
                        value => "Australia/Brisbane"
                    },
                    {
                        text => "Australia/Broken_Hill",
                        value => "Australia/Broken_Hill"
                    },
                    {
                        text => "Australia/Currie",
                        value => "Australia/Currie"
                    },
                    {
                        text => "Australia/Darwin",
                        value => "Australia/Darwin"
                    },
                    {
                        text => "Australia/Eucla",
                        value => "Australia/Eucla"
                    },
                    {
                        text => "Australia/Hobart",
                        value => "Australia/Hobart"
                    },
                    {
                        text => "Australia/Lindeman",
                        value => "Australia/Lindeman"
                    },
                    {
                        text => "Australia/Lord_Howe",
                        value => "Australia/Lord_Howe"
                    },
                    {
                        text => "Australia/Melbourne",
                        value => "Australia/Melbourne"
                    },
                    {
                        text => "Australia/Perth",
                        value => "Australia/Perth"
                    },
                    {
                        text => "Australia/Sydney",
                        value => "Australia/Sydney"
                    },
                    {
                        text => "Europe/Amsterdam",
                        value => "Europe/Amsterdam"
                    },
                    {
                        text => "Europe/Andorra",
                        value => "Europe/Andorra"
                    },
                    {
                        text => "Europe/Astrakhan",
                        value => "Europe/Astrakhan"
                    },
                    {
                        text => "Europe/Athens",
                        value => "Europe/Athens"
                    },
                    {
                        text => "Europe/Belgrade",
                        value => "Europe/Belgrade"
                    },
                    {
                        text => "Europe/Berlin",
                        value => "Europe/Berlin"
                    },
                    {
                        text => "Europe/Brussels",
                        value => "Europe/Brussels"
                    },
                    {
                        text => "Europe/Bucharest",
                        value => "Europe/Bucharest"
                    },
                    {
                        text => "Europe/Budapest",
                        value => "Europe/Budapest"
                    },
                    {
                        text => "Europe/Chisinau",
                        value => "Europe/Chisinau"
                    },
                    {
                        text => "Europe/Copenhagen",
                        value => "Europe/Copenhagen"
                    },
                    {
                        text => "Europe/Dublin",
                        value => "Europe/Dublin"
                    },
                    {
                        text => "Europe/Gibraltar",
                        value => "Europe/Gibraltar"
                    },
                    {
                        text => "Europe/Helsinki",
                        value => "Europe/Helsinki"
                    },
                    {
                        text => "Europe/Istanbul",
                        value => "Europe/Istanbul"
                    },
                    {
                        text => "Europe/Kaliningrad",
                        value => "Europe/Kaliningrad"
                    },
                    {
                        text => "Europe/Kiev",
                        value => "Europe/Kiev"
                    },
                    {
                        text => "Europe/Kirov",
                        value => "Europe/Kirov"
                    },
                    {
                        text => "Europe/Lisbon",
                        value => "Europe/Lisbon"
                    },
                    {
                        text => "Europe/London",
                        value => "Europe/London"
                    },
                    {
                        text => "Europe/Luxembourg",
                        value => "Europe/Luxembourg"
                    },
                    {
                        text => "Europe/Madrid",
                        value => "Europe/Madrid"
                    },
                    {
                        text => "Europe/Malta",
                        value => "Europe/Malta"
                    },
                    {
                        text => "Europe/Minsk",
                        value => "Europe/Minsk"
                    },
                    {
                        text => "Europe/Monaco",
                        value => "Europe/Monaco"
                    },
                    {
                        text => "Europe/Moscow",
                        value => "Europe/Moscow"
                    },
                    {
                        text => "Europe/Oslo",
                        value => "Europe/Oslo"
                    },
                    {
                        text => "Europe/Paris",
                        value => "Europe/Paris"
                    },
                    {
                        text => "Europe/Prague",
                        value => "Europe/Prague"
                    },
                    {
                        text => "Europe/Riga",
                        value => "Europe/Riga"
                    },
                    {
                        text => "Europe/Rome",
                        value => "Europe/Rome"
                    },
                    {
                        text => "Europe/Samara",
                        value => "Europe/Samara"
                    },
                    {
                        text => "Europe/Saratov",
                        value => "Europe/Saratov"
                    },
                    {
                        text => "Europe/Simferopol",
                        value => "Europe/Simferopol"
                    },
                    {
                        text => "Europe/Sofia",
                        value => "Europe/Sofia"
                    },
                    {
                        text => "Europe/Stockholm",
                        value => "Europe/Stockholm"
                    },
                    {
                        text => "Europe/Tallinn",
                        value => "Europe/Tallinn"
                    },
                    {
                        text => "Europe/Tirane",
                        value => "Europe/Tirane"
                    },
                    {
                        text => "Europe/Ulyanovsk",
                        value => "Europe/Ulyanovsk"
                    },
                    {
                        text => "Europe/Uzhgorod",
                        value => "Europe/Uzhgorod"
                    },
                    {
                        text => "Europe/Vienna",
                        value => "Europe/Vienna"
                    },
                    {
                        text => "Europe/Vilnius",
                        value => "Europe/Vilnius"
                    },
                    {
                        text => "Europe/Volgograd",
                        value => "Europe/Volgograd"
                    },
                    {
                        text => "Europe/Warsaw",
                        value => "Europe/Warsaw"
                    },
                    {
                        text => "Europe/Zaporozhye",
                        value => "Europe/Zaporozhye"
                    },
                    {
                        text => "Europe/Zurich",
                        value => "Europe/Zurich"
                    },
                    {
                        text => "Indian/Chagos",
                        value => "Indian/Chagos"
                    },
                    {
                        text => "Indian/Christmas",
                        value => "Indian/Christmas"
                    },
                    {
                        text => "Indian/Cocos",
                        value => "Indian/Cocos"
                    },
                    {
                        text => "Indian/Kerguelen",
                        value => "Indian/Kerguelen"
                    },
                    {
                        text => "Indian/Mahe",
                        value => "Indian/Mahe"
                    },
                    {
                        text => "Indian/Maldives",
                        value => "Indian/Maldives"
                    },
                    {
                        text => "Indian/Mauritius",
                        value => "Indian/Mauritius"
                    },
                    {
                        text => "Indian/Reunion",
                        value => "Indian/Reunion"
                    },
                    {
                        text => "Pacific/Apia",
                        value => "Pacific/Apia"
                    },
                    {
                        text => "Pacific/Auckland",
                        value => "Pacific/Auckland"
                    },
                    {
                        text => "Pacific/Bougainville",
                        value => "Pacific/Bougainville"
                    },
                    {
                        text => "Pacific/Chatham",
                        value => "Pacific/Chatham"
                    },
                    {
                        text => "Pacific/Chuuk",
                        value => "Pacific/Chuuk"
                    },
                    {
                        text => "Pacific/Easter",
                        value => "Pacific/Easter"
                    },
                    {
                        text => "Pacific/Efate",
                        value => "Pacific/Efate"
                    },
                    {
                        text => "Pacific/Enderbury",
                        value => "Pacific/Enderbury"
                    },
                    {
                        text => "Pacific/Fakaofo",
                        value => "Pacific/Fakaofo"
                    },
                    {
                        text => "Pacific/Fiji",
                        value => "Pacific/Fiji"
                    },
                    {
                        text => "Pacific/Funafuti",
                        value => "Pacific/Funafuti"
                    },
                    {
                        text => "Pacific/Galapagos",
                        value => "Pacific/Galapagos"
                    },
                    {
                        text => "Pacific/Gambier",
                        value => "Pacific/Gambier"
                    },
                    {
                        text => "Pacific/Guadalcanal",
                        value => "Pacific/Guadalcanal"
                    },
                    {
                        text => "Pacific/Guam",
                        value => "Pacific/Guam"
                    },
                    {
                        text => "Pacific/Honolulu",
                        value => "Pacific/Honolulu"
                    },
                    {
                        text => "Pacific/Kiritimati",
                        value => "Pacific/Kiritimati"
                    },
                    {
                        text => "Pacific/Kosrae",
                        value => "Pacific/Kosrae"
                    },
                    {
                        text => "Pacific/Kwajalein",
                        value => "Pacific/Kwajalein"
                    },
                    {
                        text => "Pacific/Majuro",
                        value => "Pacific/Majuro"
                    },
                    {
                        text => "Pacific/Marquesas",
                        value => "Pacific/Marquesas"
                    },
                    {
                        text => "Pacific/Nauru",
                        value => "Pacific/Nauru"
                    },
                    {
                        text => "Pacific/Niue",
                        value => "Pacific/Niue"
                    },
                    {
                        text => "Pacific/Norfolk",
                        value => "Pacific/Norfolk"
                    },
                    {
                        text => "Pacific/Noumea",
                        value => "Pacific/Noumea"
                    },
                    {
                        text => "Pacific/Pago_Pago",
                        value => "Pacific/Pago_Pago"
                    },
                    {
                        text => "Pacific/Palau",
                        value => "Pacific/Palau"
                    },
                    {
                        text => "Pacific/Pitcairn",
                        value => "Pacific/Pitcairn"
                    },
                    {
                        text => "Pacific/Pohnpei",
                        value => "Pacific/Pohnpei"
                    },
                    {
                        text => "Pacific/Port_Moresby",
                        value => "Pacific/Port_Moresby"
                    },
                    {
                        text => "Pacific/Rarotonga",
                        value => "Pacific/Rarotonga"
                    },
                    {
                        text => "Pacific/Tahiti",
                        value => "Pacific/Tahiti"
                    },
                    {
                        text => "Pacific/Tarawa",
                        value => "Pacific/Tarawa"
                    },
                    {
                        text => "Pacific/Tongatapu",
                        value => "Pacific/Tongatapu"
                    },
                    {
                        text => "Pacific/Wake",
                        value => "Pacific/Wake"
                    },
                    {
                        text => "Pacific/Wallis",
                        value => "Pacific/Wallis"
                    }
                ],
                default     => undef,
                placeholder => undef,
                required    => $false,
                type        => "string"
            }
        },
        status => 200
    }
);

$t->options_ok("/api/v1/config/scan/test1")
  ->status_is(200);

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

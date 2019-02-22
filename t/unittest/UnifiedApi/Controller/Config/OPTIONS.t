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

use Test::More tests => 13;

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
        allowed => {
            id         => undef,
            ip         => undef,
            pvid       => undef,
            taggedVlan => undef,
            trunkPort  => undef
        },
        defaults => {
            id         => undef,
            ip         => undef,
            pvid       => undef,
            taggedVlan => undef,
            trunkPort  => undef
        },
        meta => {
            id => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required => $true,
                type     => "string"
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
        placeholders => {
            id         => undef,
            ip         => undef,
            pvid       => undef,
            taggedVlan => undef,
            trunkPort  => undef
        },
        status => 200
    }
);


$t->options_ok("/api/v1/config/syslog_parsers")
  ->status_is(200)
  ->json_is(
    {
        allowed => {
            type => [
                {
                    label => "suricata_md5",
                    value => "suricata_md5"
                },
                {
                    label => "security_onion",
                    value => "security_onion"
                },
                {
                    label => "regex",
                    value => "regex"
                },
                {
                    label => "fortianalyser",
                    value => "fortianalyser"
                },
                {
                    label => "suricata",
                    value => "suricata"
                },
                {
                    label => "dhcp",
                    value => "dhcp"
                },
                {
                    label => "snort",
                    value => "snort"
                }
            ]
        },
        defaults     => {},
        placeholders => {},
        status       => 200
    }
);

$t->options_ok("/api/v1/config/syslog_parsers?type=regex")
  ->status_is(200)
  ->json_is(
    {
        allowed => {
            id       => undef,
            lines    => undef,
            loglines => undef,
            path     => undef,
            rules    => undef,
            status   => undef,
            type     => undef
        },
        defaults => {
            id       => undef,
            lines    => undef,
            loglines => undef,
            path     => undef,
            rules    => undef,
            status   => undef,
            type     => undef
        },
        meta => {
            id => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required    => $true,
                type        => "string"
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
        placeholders => {
            id       => undef,
            lines    => undef,
            loglines => undef,
            path     => undef,
            rules    => undef,
            status   => undef,
            type     => undef
        },
        status => 200
    }
);

$t->options_ok("/api/v1/config/base/general")
  ->status_is(200)
  ->json_is(
    {
        allowed => {
            dhcpservers => undef,
            domain      => undef,
            hostname    => undef,
            timezone    => [
                {
                    label => "",
                    value => ""
                },
                {
                    label => "Africa/Abidjan",
                    value => "Africa/Abidjan"
                },
                {
                    label => "Africa/Accra",
                    value => "Africa/Accra"
                },
                {
                    label => "Africa/Algiers",
                    value => "Africa/Algiers"
                },
                {
                    label => "Africa/Bissau",
                    value => "Africa/Bissau"
                },
                {
                    label => "Africa/Cairo",
                    value => "Africa/Cairo"
                },
                {
                    label => "Africa/Casablanca",
                    value => "Africa/Casablanca"
                },
                {
                    label => "Africa/Ceuta",
                    value => "Africa/Ceuta"
                },
                {
                    label => "Africa/El_Aaiun",
                    value => "Africa/El_Aaiun"
                },
                {
                    label => "Africa/Johannesburg",
                    value => "Africa/Johannesburg"
                },
                {
                    label => "Africa/Khartoum",
                    value => "Africa/Khartoum"
                },
                {
                    label => "Africa/Lagos",
                    value => "Africa/Lagos"
                },
                {
                    label => "Africa/Maputo",
                    value => "Africa/Maputo"
                },
                {
                    label => "Africa/Monrovia",
                    value => "Africa/Monrovia"
                },
                {
                    label => "Africa/Nairobi",
                    value => "Africa/Nairobi"
                },
                {
                    label => "Africa/Ndjamena",
                    value => "Africa/Ndjamena"
                },
                {
                    label => "Africa/Tripoli",
                    value => "Africa/Tripoli"
                },
                {
                    label => "Africa/Tunis",
                    value => "Africa/Tunis"
                },
                {
                    label => "Africa/Windhoek",
                    value => "Africa/Windhoek"
                },
                {
                    label => "America/Adak",
                    value => "America/Adak"
                },
                {
                    label => "America/Anchorage",
                    value => "America/Anchorage"
                },
                {
                    label => "America/Araguaina",
                    value => "America/Araguaina"
                },
                {
                    label => "America/Argentina/Buenos_Aires",
                    value => "America/Argentina/Buenos_Aires"
                },
                {
                    label => "America/Argentina/Catamarca",
                    value => "America/Argentina/Catamarca"
                },
                {
                    label => "America/Argentina/Cordoba",
                    value => "America/Argentina/Cordoba"
                },
                {
                    label => "America/Argentina/Jujuy",
                    value => "America/Argentina/Jujuy"
                },
                {
                    label => "America/Argentina/La_Rioja",
                    value => "America/Argentina/La_Rioja"
                },
                {
                    label => "America/Argentina/Mendoza",
                    value => "America/Argentina/Mendoza"
                },
                {
                    label => "America/Argentina/Rio_Gallegos",
                    value => "America/Argentina/Rio_Gallegos"
                },
                {
                    label => "America/Argentina/Salta",
                    value => "America/Argentina/Salta"
                },
                {
                    label => "America/Argentina/San_Juan",
                    value => "America/Argentina/San_Juan"
                },
                {
                    label => "America/Argentina/San_Luis",
                    value => "America/Argentina/San_Luis"
                },
                {
                    label => "America/Argentina/Tucuman",
                    value => "America/Argentina/Tucuman"
                },
                {
                    label => "America/Argentina/Ushuaia",
                    value => "America/Argentina/Ushuaia"
                },
                {
                    label => "America/Asuncion",
                    value => "America/Asuncion"
                },
                {
                    label => "America/Atikokan",
                    value => "America/Atikokan"
                },
                {
                    label => "America/Bahia",
                    value => "America/Bahia"
                },
                {
                    label => "America/Bahia_Banderas",
                    value => "America/Bahia_Banderas"
                },
                {
                    label => "America/Barbados",
                    value => "America/Barbados"
                },
                {
                    label => "America/Belem",
                    value => "America/Belem"
                },
                {
                    label => "America/Belize",
                    value => "America/Belize"
                },
                {
                    label => "America/Blanc-Sablon",
                    value => "America/Blanc-Sablon"
                },
                {
                    label => "America/Boa_Vista",
                    value => "America/Boa_Vista"
                },
                {
                    label => "America/Bogota",
                    value => "America/Bogota"
                },
                {
                    label => "America/Boise",
                    value => "America/Boise"
                },
                {
                    label => "America/Cambridge_Bay",
                    value => "America/Cambridge_Bay"
                },
                {
                    label => "America/Campo_Grande",
                    value => "America/Campo_Grande"
                },
                {
                    label => "America/Cancun",
                    value => "America/Cancun"
                },
                {
                    label => "America/Caracas",
                    value => "America/Caracas"
                },
                {
                    label => "America/Cayenne",
                    value => "America/Cayenne"
                },
                {
                    label => "America/Chicago",
                    value => "America/Chicago"
                },
                {
                    label => "America/Chihuahua",
                    value => "America/Chihuahua"
                },
                {
                    label => "America/Costa_Rica",
                    value => "America/Costa_Rica"
                },
                {
                    label => "America/Creston",
                    value => "America/Creston"
                },
                {
                    label => "America/Cuiaba",
                    value => "America/Cuiaba"
                },
                {
                    label => "America/Curacao",
                    value => "America/Curacao"
                },
                {
                    label => "America/Danmarkshavn",
                    value => "America/Danmarkshavn"
                },
                {
                    label => "America/Dawson",
                    value => "America/Dawson"
                },
                {
                    label => "America/Dawson_Creek",
                    value => "America/Dawson_Creek"
                },
                {
                    label => "America/Denver",
                    value => "America/Denver"
                },
                {
                    label => "America/Detroit",
                    value => "America/Detroit"
                },
                {
                    label => "America/Edmonton",
                    value => "America/Edmonton"
                },
                {
                    label => "America/Eirunepe",
                    value => "America/Eirunepe"
                },
                {
                    label => "America/El_Salvador",
                    value => "America/El_Salvador"
                },
                {
                    label => "America/Fort_Nelson",
                    value => "America/Fort_Nelson"
                },
                {
                    label => "America/Fortaleza",
                    value => "America/Fortaleza"
                },
                {
                    label => "America/Glace_Bay",
                    value => "America/Glace_Bay"
                },
                {
                    label => "America/Godthab",
                    value => "America/Godthab"
                },
                {
                    label => "America/Goose_Bay",
                    value => "America/Goose_Bay"
                },
                {
                    label => "America/Grand_Turk",
                    value => "America/Grand_Turk"
                },
                {
                    label => "America/Guatemala",
                    value => "America/Guatemala"
                },
                {
                    label => "America/Guayaquil",
                    value => "America/Guayaquil"
                },
                {
                    label => "America/Guyana",
                    value => "America/Guyana"
                },
                {
                    label => "America/Halifax",
                    value => "America/Halifax"
                },
                {
                    label => "America/Havana",
                    value => "America/Havana"
                },
                {
                    label => "America/Hermosillo",
                    value => "America/Hermosillo"
                },
                {
                    label => "America/Indiana/Indianapolis",
                    value => "America/Indiana/Indianapolis"
                },
                {
                    label => "America/Indiana/Knox",
                    value => "America/Indiana/Knox"
                },
                {
                    label => "America/Indiana/Marengo",
                    value => "America/Indiana/Marengo"
                },
                {
                    label => "America/Indiana/Petersburg",
                    value => "America/Indiana/Petersburg"
                },
                {
                    label => "America/Indiana/Tell_City",
                    value => "America/Indiana/Tell_City"
                },
                {
                    label => "America/Indiana/Vevay",
                    value => "America/Indiana/Vevay"
                },
                {
                    label => "America/Indiana/Vincennes",
                    value => "America/Indiana/Vincennes"
                },
                {
                    label => "America/Indiana/Winamac",
                    value => "America/Indiana/Winamac"
                },
                {
                    label => "America/Inuvik",
                    value => "America/Inuvik"
                },
                {
                    label => "America/Iqaluit",
                    value => "America/Iqaluit"
                },
                {
                    label => "America/Jamaica",
                    value => "America/Jamaica"
                },
                {
                    label => "America/Juneau",
                    value => "America/Juneau"
                },
                {
                    label => "America/Kentucky/Louisville",
                    value => "America/Kentucky/Louisville"
                },
                {
                    label => "America/Kentucky/Monticello",
                    value => "America/Kentucky/Monticello"
                },
                {
                    label => "America/La_Paz",
                    value => "America/La_Paz"
                },
                {
                    label => "America/Lima",
                    value => "America/Lima"
                },
                {
                    label => "America/Los_Angeles",
                    value => "America/Los_Angeles"
                },
                {
                    label => "America/Maceio",
                    value => "America/Maceio"
                },
                {
                    label => "America/Managua",
                    value => "America/Managua"
                },
                {
                    label => "America/Manaus",
                    value => "America/Manaus"
                },
                {
                    label => "America/Martinique",
                    value => "America/Martinique"
                },
                {
                    label => "America/Matamoros",
                    value => "America/Matamoros"
                },
                {
                    label => "America/Mazatlan",
                    value => "America/Mazatlan"
                },
                {
                    label => "America/Menominee",
                    value => "America/Menominee"
                },
                {
                    label => "America/Merida",
                    value => "America/Merida"
                },
                {
                    label => "America/Metlakatla",
                    value => "America/Metlakatla"
                },
                {
                    label => "America/Mexico_City",
                    value => "America/Mexico_City"
                },
                {
                    label => "America/Miquelon",
                    value => "America/Miquelon"
                },
                {
                    label => "America/Moncton",
                    value => "America/Moncton"
                },
                {
                    label => "America/Monterrey",
                    value => "America/Monterrey"
                },
                {
                    label => "America/Montevideo",
                    value => "America/Montevideo"
                },
                {
                    label => "America/Nassau",
                    value => "America/Nassau"
                },
                {
                    label => "America/New_York",
                    value => "America/New_York"
                },
                {
                    label => "America/Nipigon",
                    value => "America/Nipigon"
                },
                {
                    label => "America/Nome",
                    value => "America/Nome"
                },
                {
                    label => "America/Noronha",
                    value => "America/Noronha"
                },
                {
                    label => "America/North_Dakota/Beulah",
                    value => "America/North_Dakota/Beulah"
                },
                {
                    label => "America/North_Dakota/Center",
                    value => "America/North_Dakota/Center"
                },
                {
                    label => "America/North_Dakota/New_Salem",
                    value => "America/North_Dakota/New_Salem"
                },
                {
                    label => "America/Ojinaga",
                    value => "America/Ojinaga"
                },
                {
                    label => "America/Panama",
                    value => "America/Panama"
                },
                {
                    label => "America/Pangnirtung",
                    value => "America/Pangnirtung"
                },
                {
                    label => "America/Paramaribo",
                    value => "America/Paramaribo"
                },
                {
                    label => "America/Phoenix",
                    value => "America/Phoenix"
                },
                {
                    label => "America/Port-au-Prince",
                    value => "America/Port-au-Prince"
                },
                {
                    label => "America/Port_of_Spain",
                    value => "America/Port_of_Spain"
                },
                {
                    label => "America/Porto_Velho",
                    value => "America/Porto_Velho"
                },
                {
                    label => "America/Puerto_Rico",
                    value => "America/Puerto_Rico"
                },
                {
                    label => "America/Punta_Arenas",
                    value => "America/Punta_Arenas"
                },
                {
                    label => "America/Rainy_River",
                    value => "America/Rainy_River"
                },
                {
                    label => "America/Rankin_Inlet",
                    value => "America/Rankin_Inlet"
                },
                {
                    label => "America/Recife",
                    value => "America/Recife"
                },
                {
                    label => "America/Regina",
                    value => "America/Regina"
                },
                {
                    label => "America/Resolute",
                    value => "America/Resolute"
                },
                {
                    label => "America/Rio_Branco",
                    value => "America/Rio_Branco"
                },
                {
                    label => "America/Santarem",
                    value => "America/Santarem"
                },
                {
                    label => "America/Santiago",
                    value => "America/Santiago"
                },
                {
                    label => "America/Santo_Domingo",
                    value => "America/Santo_Domingo"
                },
                {
                    label => "America/Sao_Paulo",
                    value => "America/Sao_Paulo"
                },
                {
                    label => "America/Scoresbysund",
                    value => "America/Scoresbysund"
                },
                {
                    label => "America/Sitka",
                    value => "America/Sitka"
                },
                {
                    label => "America/St_Johns",
                    value => "America/St_Johns"
                },
                {
                    label => "America/Swift_Current",
                    value => "America/Swift_Current"
                },
                {
                    label => "America/Tegucigalpa",
                    value => "America/Tegucigalpa"
                },
                {
                    label => "America/Thule",
                    value => "America/Thule"
                },
                {
                    label => "America/Thunder_Bay",
                    value => "America/Thunder_Bay"
                },
                {
                    label => "America/Tijuana",
                    value => "America/Tijuana"
                },
                {
                    label => "America/Toronto",
                    value => "America/Toronto"
                },
                {
                    label => "America/Vancouver",
                    value => "America/Vancouver"
                },
                {
                    label => "America/Whitehorse",
                    value => "America/Whitehorse"
                },
                {
                    label => "America/Winnipeg",
                    value => "America/Winnipeg"
                },
                {
                    label => "America/Yakutat",
                    value => "America/Yakutat"
                },
                {
                    label => "America/Yellowknife",
                    value => "America/Yellowknife"
                },
                {
                    label => "Antarctica/Casey",
                    value => "Antarctica/Casey"
                },
                {
                    label => "Antarctica/Davis",
                    value => "Antarctica/Davis"
                },
                {
                    label => "Antarctica/DumontDUrville",
                    value => "Antarctica/DumontDUrville"
                },
                {
                    label => "Antarctica/Macquarie",
                    value => "Antarctica/Macquarie"
                },
                {
                    label => "Antarctica/Mawson",
                    value => "Antarctica/Mawson"
                },
                {
                    label => "Antarctica/Palmer",
                    value => "Antarctica/Palmer"
                },
                {
                    label => "Antarctica/Rothera",
                    value => "Antarctica/Rothera"
                },
                {
                    label => "Antarctica/Syowa",
                    value => "Antarctica/Syowa"
                },
                {
                    label => "Antarctica/Troll",
                    value => "Antarctica/Troll"
                },
                {
                    label => "Antarctica/Vostok",
                    value => "Antarctica/Vostok"
                },
                {
                    label => "Asia/Almaty",
                    value => "Asia/Almaty"
                },
                {
                    label => "Asia/Amman",
                    value => "Asia/Amman"
                },
                {
                    label => "Asia/Anadyr",
                    value => "Asia/Anadyr"
                },
                {
                    label => "Asia/Aqtau",
                    value => "Asia/Aqtau"
                },
                {
                    label => "Asia/Aqtobe",
                    value => "Asia/Aqtobe"
                },
                {
                    label => "Asia/Ashgabat",
                    value => "Asia/Ashgabat"
                },
                {
                    label => "Asia/Atyrau",
                    value => "Asia/Atyrau"
                },
                {
                    label => "Asia/Baghdad",
                    value => "Asia/Baghdad"
                },
                {
                    label => "Asia/Baku",
                    value => "Asia/Baku"
                },
                {
                    label => "Asia/Bangkok",
                    value => "Asia/Bangkok"
                },
                {
                    label => "Asia/Barnaul",
                    value => "Asia/Barnaul"
                },
                {
                    label => "Asia/Beirut",
                    value => "Asia/Beirut"
                },
                {
                    label => "Asia/Bishkek",
                    value => "Asia/Bishkek"
                },
                {
                    label => "Asia/Brunei",
                    value => "Asia/Brunei"
                },
                {
                    label => "Asia/Chita",
                    value => "Asia/Chita"
                },
                {
                    label => "Asia/Choibalsan",
                    value => "Asia/Choibalsan"
                },
                {
                    label => "Asia/Colombo",
                    value => "Asia/Colombo"
                },
                {
                    label => "Asia/Damascus",
                    value => "Asia/Damascus"
                },
                {
                    label => "Asia/Dhaka",
                    value => "Asia/Dhaka"
                },
                {
                    label => "Asia/Dili",
                    value => "Asia/Dili"
                },
                {
                    label => "Asia/Dubai",
                    value => "Asia/Dubai"
                },
                {
                    label => "Asia/Dushanbe",
                    value => "Asia/Dushanbe"
                },
                {
                    label => "Asia/Famagusta",
                    value => "Asia/Famagusta"
                },
                {
                    label => "Asia/Gaza",
                    value => "Asia/Gaza"
                },
                {
                    label => "Asia/Hebron",
                    value => "Asia/Hebron"
                },
                {
                    label => "Asia/Ho_Chi_Minh",
                    value => "Asia/Ho_Chi_Minh"
                },
                {
                    label => "Asia/Hong_Kong",
                    value => "Asia/Hong_Kong"
                },
                {
                    label => "Asia/Hovd",
                    value => "Asia/Hovd"
                },
                {
                    label => "Asia/Irkutsk",
                    value => "Asia/Irkutsk"
                },
                {
                    label => "Asia/Jakarta",
                    value => "Asia/Jakarta"
                },
                {
                    label => "Asia/Jayapura",
                    value => "Asia/Jayapura"
                },
                {
                    label => "Asia/Jerusalem",
                    value => "Asia/Jerusalem"
                },
                {
                    label => "Asia/Kabul",
                    value => "Asia/Kabul"
                },
                {
                    label => "Asia/Kamchatka",
                    value => "Asia/Kamchatka"
                },
                {
                    label => "Asia/Karachi",
                    value => "Asia/Karachi"
                },
                {
                    label => "Asia/Kathmandu",
                    value => "Asia/Kathmandu"
                },
                {
                    label => "Asia/Khandyga",
                    value => "Asia/Khandyga"
                },
                {
                    label => "Asia/Kolkata",
                    value => "Asia/Kolkata"
                },
                {
                    label => "Asia/Krasnoyarsk",
                    value => "Asia/Krasnoyarsk"
                },
                {
                    label => "Asia/Kuala_Lumpur",
                    value => "Asia/Kuala_Lumpur"
                },
                {
                    label => "Asia/Kuching",
                    value => "Asia/Kuching"
                },
                {
                    label => "Asia/Macau",
                    value => "Asia/Macau"
                },
                {
                    label => "Asia/Magadan",
                    value => "Asia/Magadan"
                },
                {
                    label => "Asia/Makassar",
                    value => "Asia/Makassar"
                },
                {
                    label => "Asia/Manila",
                    value => "Asia/Manila"
                },
                {
                    label => "Asia/Nicosia",
                    value => "Asia/Nicosia"
                },
                {
                    label => "Asia/Novokuznetsk",
                    value => "Asia/Novokuznetsk"
                },
                {
                    label => "Asia/Novosibirsk",
                    value => "Asia/Novosibirsk"
                },
                {
                    label => "Asia/Omsk",
                    value => "Asia/Omsk"
                },
                {
                    label => "Asia/Oral",
                    value => "Asia/Oral"
                },
                {
                    label => "Asia/Pontianak",
                    value => "Asia/Pontianak"
                },
                {
                    label => "Asia/Pyongyang",
                    value => "Asia/Pyongyang"
                },
                {
                    label => "Asia/Qatar",
                    value => "Asia/Qatar"
                },
                {
                    label => "Asia/Qyzylorda",
                    value => "Asia/Qyzylorda"
                },
                {
                    label => "Asia/Riyadh",
                    value => "Asia/Riyadh"
                },
                {
                    label => "Asia/Sakhalin",
                    value => "Asia/Sakhalin"
                },
                {
                    label => "Asia/Samarkand",
                    value => "Asia/Samarkand"
                },
                {
                    label => "Asia/Seoul",
                    value => "Asia/Seoul"
                },
                {
                    label => "Asia/Shanghai",
                    value => "Asia/Shanghai"
                },
                {
                    label => "Asia/Singapore",
                    value => "Asia/Singapore"
                },
                {
                    label => "Asia/Srednekolymsk",
                    value => "Asia/Srednekolymsk"
                },
                {
                    label => "Asia/Taipei",
                    value => "Asia/Taipei"
                },
                {
                    label => "Asia/Tashkent",
                    value => "Asia/Tashkent"
                },
                {
                    label => "Asia/Tbilisi",
                    value => "Asia/Tbilisi"
                },
                {
                    label => "Asia/Tehran",
                    value => "Asia/Tehran"
                },
                {
                    label => "Asia/Thimphu",
                    value => "Asia/Thimphu"
                },
                {
                    label => "Asia/Tokyo",
                    value => "Asia/Tokyo"
                },
                {
                    label => "Asia/Tomsk",
                    value => "Asia/Tomsk"
                },
                {
                    label => "Asia/Ulaanbaatar",
                    value => "Asia/Ulaanbaatar"
                },
                {
                    label => "Asia/Urumqi",
                    value => "Asia/Urumqi"
                },
                {
                    label => "Asia/Ust-Nera",
                    value => "Asia/Ust-Nera"
                },
                {
                    label => "Asia/Vladivostok",
                    value => "Asia/Vladivostok"
                },
                {
                    label => "Asia/Yakutsk",
                    value => "Asia/Yakutsk"
                },
                {
                    label => "Asia/Yangon",
                    value => "Asia/Yangon"
                },
                {
                    label => "Asia/Yekaterinburg",
                    value => "Asia/Yekaterinburg"
                },
                {
                    label => "Asia/Yerevan",
                    value => "Asia/Yerevan"
                },
                {
                    label => "Atlantic/Azores",
                    value => "Atlantic/Azores"
                },
                {
                    label => "Atlantic/Bermuda",
                    value => "Atlantic/Bermuda"
                },
                {
                    label => "Atlantic/Canary",
                    value => "Atlantic/Canary"
                },
                {
                    label => "Atlantic/Cape_Verde",
                    value => "Atlantic/Cape_Verde"
                },
                {
                    label => "Atlantic/Faroe",
                    value => "Atlantic/Faroe"
                },
                {
                    label => "Atlantic/Madeira",
                    value => "Atlantic/Madeira"
                },
                {
                    label => "Atlantic/Reykjavik",
                    value => "Atlantic/Reykjavik"
                },
                {
                    label => "Atlantic/South_Georgia",
                    value => "Atlantic/South_Georgia"
                },
                {
                    label => "Atlantic/Stanley",
                    value => "Atlantic/Stanley"
                },
                {
                    label => "Australia/Adelaide",
                    value => "Australia/Adelaide"
                },
                {
                    label => "Australia/Brisbane",
                    value => "Australia/Brisbane"
                },
                {
                    label => "Australia/Broken_Hill",
                    value => "Australia/Broken_Hill"
                },
                {
                    label => "Australia/Currie",
                    value => "Australia/Currie"
                },
                {
                    label => "Australia/Darwin",
                    value => "Australia/Darwin"
                },
                {
                    label => "Australia/Eucla",
                    value => "Australia/Eucla"
                },
                {
                    label => "Australia/Hobart",
                    value => "Australia/Hobart"
                },
                {
                    label => "Australia/Lindeman",
                    value => "Australia/Lindeman"
                },
                {
                    label => "Australia/Lord_Howe",
                    value => "Australia/Lord_Howe"
                },
                {
                    label => "Australia/Melbourne",
                    value => "Australia/Melbourne"
                },
                {
                    label => "Australia/Perth",
                    value => "Australia/Perth"
                },
                {
                    label => "Australia/Sydney",
                    value => "Australia/Sydney"
                },
                {
                    label => "Europe/Amsterdam",
                    value => "Europe/Amsterdam"
                },
                {
                    label => "Europe/Andorra",
                    value => "Europe/Andorra"
                },
                {
                    label => "Europe/Astrakhan",
                    value => "Europe/Astrakhan"
                },
                {
                    label => "Europe/Athens",
                    value => "Europe/Athens"
                },
                {
                    label => "Europe/Belgrade",
                    value => "Europe/Belgrade"
                },
                {
                    label => "Europe/Berlin",
                    value => "Europe/Berlin"
                },
                {
                    label => "Europe/Brussels",
                    value => "Europe/Brussels"
                },
                {
                    label => "Europe/Bucharest",
                    value => "Europe/Bucharest"
                },
                {
                    label => "Europe/Budapest",
                    value => "Europe/Budapest"
                },
                {
                    label => "Europe/Chisinau",
                    value => "Europe/Chisinau"
                },
                {
                    label => "Europe/Copenhagen",
                    value => "Europe/Copenhagen"
                },
                {
                    label => "Europe/Dublin",
                    value => "Europe/Dublin"
                },
                {
                    label => "Europe/Gibraltar",
                    value => "Europe/Gibraltar"
                },
                {
                    label => "Europe/Helsinki",
                    value => "Europe/Helsinki"
                },
                {
                    label => "Europe/Istanbul",
                    value => "Europe/Istanbul"
                },
                {
                    label => "Europe/Kaliningrad",
                    value => "Europe/Kaliningrad"
                },
                {
                    label => "Europe/Kiev",
                    value => "Europe/Kiev"
                },
                {
                    label => "Europe/Kirov",
                    value => "Europe/Kirov"
                },
                {
                    label => "Europe/Lisbon",
                    value => "Europe/Lisbon"
                },
                {
                    label => "Europe/London",
                    value => "Europe/London"
                },
                {
                    label => "Europe/Luxembourg",
                    value => "Europe/Luxembourg"
                },
                {
                    label => "Europe/Madrid",
                    value => "Europe/Madrid"
                },
                {
                    label => "Europe/Malta",
                    value => "Europe/Malta"
                },
                {
                    label => "Europe/Minsk",
                    value => "Europe/Minsk"
                },
                {
                    label => "Europe/Monaco",
                    value => "Europe/Monaco"
                },
                {
                    label => "Europe/Moscow",
                    value => "Europe/Moscow"
                },
                {
                    label => "Europe/Oslo",
                    value => "Europe/Oslo"
                },
                {
                    label => "Europe/Paris",
                    value => "Europe/Paris"
                },
                {
                    label => "Europe/Prague",
                    value => "Europe/Prague"
                },
                {
                    label => "Europe/Riga",
                    value => "Europe/Riga"
                },
                {
                    label => "Europe/Rome",
                    value => "Europe/Rome"
                },
                {
                    label => "Europe/Samara",
                    value => "Europe/Samara"
                },
                {
                    label => "Europe/Saratov",
                    value => "Europe/Saratov"
                },
                {
                    label => "Europe/Simferopol",
                    value => "Europe/Simferopol"
                },
                {
                    label => "Europe/Sofia",
                    value => "Europe/Sofia"
                },
                {
                    label => "Europe/Stockholm",
                    value => "Europe/Stockholm"
                },
                {
                    label => "Europe/Tallinn",
                    value => "Europe/Tallinn"
                },
                {
                    label => "Europe/Tirane",
                    value => "Europe/Tirane"
                },
                {
                    label => "Europe/Ulyanovsk",
                    value => "Europe/Ulyanovsk"
                },
                {
                    label => "Europe/Uzhgorod",
                    value => "Europe/Uzhgorod"
                },
                {
                    label => "Europe/Vienna",
                    value => "Europe/Vienna"
                },
                {
                    label => "Europe/Vilnius",
                    value => "Europe/Vilnius"
                },
                {
                    label => "Europe/Volgograd",
                    value => "Europe/Volgograd"
                },
                {
                    label => "Europe/Warsaw",
                    value => "Europe/Warsaw"
                },
                {
                    label => "Europe/Zaporozhye",
                    value => "Europe/Zaporozhye"
                },
                {
                    label => "Europe/Zurich",
                    value => "Europe/Zurich"
                },
                {
                    label => "Indian/Chagos",
                    value => "Indian/Chagos"
                },
                {
                    label => "Indian/Christmas",
                    value => "Indian/Christmas"
                },
                {
                    label => "Indian/Cocos",
                    value => "Indian/Cocos"
                },
                {
                    label => "Indian/Kerguelen",
                    value => "Indian/Kerguelen"
                },
                {
                    label => "Indian/Mahe",
                    value => "Indian/Mahe"
                },
                {
                    label => "Indian/Maldives",
                    value => "Indian/Maldives"
                },
                {
                    label => "Indian/Mauritius",
                    value => "Indian/Mauritius"
                },
                {
                    label => "Indian/Reunion",
                    value => "Indian/Reunion"
                },
                {
                    label => "Pacific/Apia",
                    value => "Pacific/Apia"
                },
                {
                    label => "Pacific/Auckland",
                    value => "Pacific/Auckland"
                },
                {
                    label => "Pacific/Bougainville",
                    value => "Pacific/Bougainville"
                },
                {
                    label => "Pacific/Chatham",
                    value => "Pacific/Chatham"
                },
                {
                    label => "Pacific/Chuuk",
                    value => "Pacific/Chuuk"
                },
                {
                    label => "Pacific/Easter",
                    value => "Pacific/Easter"
                },
                {
                    label => "Pacific/Efate",
                    value => "Pacific/Efate"
                },
                {
                    label => "Pacific/Enderbury",
                    value => "Pacific/Enderbury"
                },
                {
                    label => "Pacific/Fakaofo",
                    value => "Pacific/Fakaofo"
                },
                {
                    label => "Pacific/Fiji",
                    value => "Pacific/Fiji"
                },
                {
                    label => "Pacific/Funafuti",
                    value => "Pacific/Funafuti"
                },
                {
                    label => "Pacific/Galapagos",
                    value => "Pacific/Galapagos"
                },
                {
                    label => "Pacific/Gambier",
                    value => "Pacific/Gambier"
                },
                {
                    label => "Pacific/Guadalcanal",
                    value => "Pacific/Guadalcanal"
                },
                {
                    label => "Pacific/Guam",
                    value => "Pacific/Guam"
                },
                {
                    label => "Pacific/Honolulu",
                    value => "Pacific/Honolulu"
                },
                {
                    label => "Pacific/Kiritimati",
                    value => "Pacific/Kiritimati"
                },
                {
                    label => "Pacific/Kosrae",
                    value => "Pacific/Kosrae"
                },
                {
                    label => "Pacific/Kwajalein",
                    value => "Pacific/Kwajalein"
                },
                {
                    label => "Pacific/Majuro",
                    value => "Pacific/Majuro"
                },
                {
                    label => "Pacific/Marquesas",
                    value => "Pacific/Marquesas"
                },
                {
                    label => "Pacific/Nauru",
                    value => "Pacific/Nauru"
                },
                {
                    label => "Pacific/Niue",
                    value => "Pacific/Niue"
                },
                {
                    label => "Pacific/Norfolk",
                    value => "Pacific/Norfolk"
                },
                {
                    label => "Pacific/Noumea",
                    value => "Pacific/Noumea"
                },
                {
                    label => "Pacific/Pago_Pago",
                    value => "Pacific/Pago_Pago"
                },
                {
                    label => "Pacific/Palau",
                    value => "Pacific/Palau"
                },
                {
                    label => "Pacific/Pitcairn",
                    value => "Pacific/Pitcairn"
                },
                {
                    label => "Pacific/Pohnpei",
                    value => "Pacific/Pohnpei"
                },
                {
                    label => "Pacific/Port_Moresby",
                    value => "Pacific/Port_Moresby"
                },
                {
                    label => "Pacific/Rarotonga",
                    value => "Pacific/Rarotonga"
                },
                {
                    label => "Pacific/Tahiti",
                    value => "Pacific/Tahiti"
                },
                {
                    label => "Pacific/Tarawa",
                    value => "Pacific/Tarawa"
                },
                {
                    label => "Pacific/Tongatapu",
                    value => "Pacific/Tongatapu"
                },
                {
                    label => "Pacific/Wake",
                    value => "Pacific/Wake"
                },
                {
                    label => "Pacific/Wallis",
                    value => "Pacific/Wallis"
                }
            ]
        },
        defaults => {
            dhcpservers => undef,
            domain      => undef,
            hostname    => undef,
            timezone    => undef
        },
        meta => {
            dhcpservers => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required    => $false,
                type        => "string"
            },
            domain => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required    => $false,
                type        => "string"
            },
            hostname => {
                allowed     => undef,
                default     => undef,
                placeholder => undef,
                required    => $false,
                type        => "string"
            },
            timezone => {
                allowed => [
                    {
                        label => "",
                        value => ""
                    },
                    {
                        label => "Africa/Abidjan",
                        value => "Africa/Abidjan"
                    },
                    {
                        label => "Africa/Accra",
                        value => "Africa/Accra"
                    },
                    {
                        label => "Africa/Algiers",
                        value => "Africa/Algiers"
                    },
                    {
                        label => "Africa/Bissau",
                        value => "Africa/Bissau"
                    },
                    {
                        label => "Africa/Cairo",
                        value => "Africa/Cairo"
                    },
                    {
                        label => "Africa/Casablanca",
                        value => "Africa/Casablanca"
                    },
                    {
                        label => "Africa/Ceuta",
                        value => "Africa/Ceuta"
                    },
                    {
                        label => "Africa/El_Aaiun",
                        value => "Africa/El_Aaiun"
                    },
                    {
                        label => "Africa/Johannesburg",
                        value => "Africa/Johannesburg"
                    },
                    {
                        label => "Africa/Khartoum",
                        value => "Africa/Khartoum"
                    },
                    {
                        label => "Africa/Lagos",
                        value => "Africa/Lagos"
                    },
                    {
                        label => "Africa/Maputo",
                        value => "Africa/Maputo"
                    },
                    {
                        label => "Africa/Monrovia",
                        value => "Africa/Monrovia"
                    },
                    {
                        label => "Africa/Nairobi",
                        value => "Africa/Nairobi"
                    },
                    {
                        label => "Africa/Ndjamena",
                        value => "Africa/Ndjamena"
                    },
                    {
                        label => "Africa/Tripoli",
                        value => "Africa/Tripoli"
                    },
                    {
                        label => "Africa/Tunis",
                        value => "Africa/Tunis"
                    },
                    {
                        label => "Africa/Windhoek",
                        value => "Africa/Windhoek"
                    },
                    {
                        label => "America/Adak",
                        value => "America/Adak"
                    },
                    {
                        label => "America/Anchorage",
                        value => "America/Anchorage"
                    },
                    {
                        label => "America/Araguaina",
                        value => "America/Araguaina"
                    },
                    {
                        label => "America/Argentina/Buenos_Aires",
                        value => "America/Argentina/Buenos_Aires"
                    },
                    {
                        label => "America/Argentina/Catamarca",
                        value => "America/Argentina/Catamarca"
                    },
                    {
                        label => "America/Argentina/Cordoba",
                        value => "America/Argentina/Cordoba"
                    },
                    {
                        label => "America/Argentina/Jujuy",
                        value => "America/Argentina/Jujuy"
                    },
                    {
                        label => "America/Argentina/La_Rioja",
                        value => "America/Argentina/La_Rioja"
                    },
                    {
                        label => "America/Argentina/Mendoza",
                        value => "America/Argentina/Mendoza"
                    },
                    {
                        label => "America/Argentina/Rio_Gallegos",
                        value => "America/Argentina/Rio_Gallegos"
                    },
                    {
                        label => "America/Argentina/Salta",
                        value => "America/Argentina/Salta"
                    },
                    {
                        label => "America/Argentina/San_Juan",
                        value => "America/Argentina/San_Juan"
                    },
                    {
                        label => "America/Argentina/San_Luis",
                        value => "America/Argentina/San_Luis"
                    },
                    {
                        label => "America/Argentina/Tucuman",
                        value => "America/Argentina/Tucuman"
                    },
                    {
                        label => "America/Argentina/Ushuaia",
                        value => "America/Argentina/Ushuaia"
                    },
                    {
                        label => "America/Asuncion",
                        value => "America/Asuncion"
                    },
                    {
                        label => "America/Atikokan",
                        value => "America/Atikokan"
                    },
                    {
                        label => "America/Bahia",
                        value => "America/Bahia"
                    },
                    {
                        label => "America/Bahia_Banderas",
                        value => "America/Bahia_Banderas"
                    },
                    {
                        label => "America/Barbados",
                        value => "America/Barbados"
                    },
                    {
                        label => "America/Belem",
                        value => "America/Belem"
                    },
                    {
                        label => "America/Belize",
                        value => "America/Belize"
                    },
                    {
                        label => "America/Blanc-Sablon",
                        value => "America/Blanc-Sablon"
                    },
                    {
                        label => "America/Boa_Vista",
                        value => "America/Boa_Vista"
                    },
                    {
                        label => "America/Bogota",
                        value => "America/Bogota"
                    },
                    {
                        label => "America/Boise",
                        value => "America/Boise"
                    },
                    {
                        label => "America/Cambridge_Bay",
                        value => "America/Cambridge_Bay"
                    },
                    {
                        label => "America/Campo_Grande",
                        value => "America/Campo_Grande"
                    },
                    {
                        label => "America/Cancun",
                        value => "America/Cancun"
                    },
                    {
                        label => "America/Caracas",
                        value => "America/Caracas"
                    },
                    {
                        label => "America/Cayenne",
                        value => "America/Cayenne"
                    },
                    {
                        label => "America/Chicago",
                        value => "America/Chicago"
                    },
                    {
                        label => "America/Chihuahua",
                        value => "America/Chihuahua"
                    },
                    {
                        label => "America/Costa_Rica",
                        value => "America/Costa_Rica"
                    },
                    {
                        label => "America/Creston",
                        value => "America/Creston"
                    },
                    {
                        label => "America/Cuiaba",
                        value => "America/Cuiaba"
                    },
                    {
                        label => "America/Curacao",
                        value => "America/Curacao"
                    },
                    {
                        label => "America/Danmarkshavn",
                        value => "America/Danmarkshavn"
                    },
                    {
                        label => "America/Dawson",
                        value => "America/Dawson"
                    },
                    {
                        label => "America/Dawson_Creek",
                        value => "America/Dawson_Creek"
                    },
                    {
                        label => "America/Denver",
                        value => "America/Denver"
                    },
                    {
                        label => "America/Detroit",
                        value => "America/Detroit"
                    },
                    {
                        label => "America/Edmonton",
                        value => "America/Edmonton"
                    },
                    {
                        label => "America/Eirunepe",
                        value => "America/Eirunepe"
                    },
                    {
                        label => "America/El_Salvador",
                        value => "America/El_Salvador"
                    },
                    {
                        label => "America/Fort_Nelson",
                        value => "America/Fort_Nelson"
                    },
                    {
                        label => "America/Fortaleza",
                        value => "America/Fortaleza"
                    },
                    {
                        label => "America/Glace_Bay",
                        value => "America/Glace_Bay"
                    },
                    {
                        label => "America/Godthab",
                        value => "America/Godthab"
                    },
                    {
                        label => "America/Goose_Bay",
                        value => "America/Goose_Bay"
                    },
                    {
                        label => "America/Grand_Turk",
                        value => "America/Grand_Turk"
                    },
                    {
                        label => "America/Guatemala",
                        value => "America/Guatemala"
                    },
                    {
                        label => "America/Guayaquil",
                        value => "America/Guayaquil"
                    },
                    {
                        label => "America/Guyana",
                        value => "America/Guyana"
                    },
                    {
                        label => "America/Halifax",
                        value => "America/Halifax"
                    },
                    {
                        label => "America/Havana",
                        value => "America/Havana"
                    },
                    {
                        label => "America/Hermosillo",
                        value => "America/Hermosillo"
                    },
                    {
                        label => "America/Indiana/Indianapolis",
                        value => "America/Indiana/Indianapolis"
                    },
                    {
                        label => "America/Indiana/Knox",
                        value => "America/Indiana/Knox"
                    },
                    {
                        label => "America/Indiana/Marengo",
                        value => "America/Indiana/Marengo"
                    },
                    {
                        label => "America/Indiana/Petersburg",
                        value => "America/Indiana/Petersburg"
                    },
                    {
                        label => "America/Indiana/Tell_City",
                        value => "America/Indiana/Tell_City"
                    },
                    {
                        label => "America/Indiana/Vevay",
                        value => "America/Indiana/Vevay"
                    },
                    {
                        label => "America/Indiana/Vincennes",
                        value => "America/Indiana/Vincennes"
                    },
                    {
                        label => "America/Indiana/Winamac",
                        value => "America/Indiana/Winamac"
                    },
                    {
                        label => "America/Inuvik",
                        value => "America/Inuvik"
                    },
                    {
                        label => "America/Iqaluit",
                        value => "America/Iqaluit"
                    },
                    {
                        label => "America/Jamaica",
                        value => "America/Jamaica"
                    },
                    {
                        label => "America/Juneau",
                        value => "America/Juneau"
                    },
                    {
                        label => "America/Kentucky/Louisville",
                        value => "America/Kentucky/Louisville"
                    },
                    {
                        label => "America/Kentucky/Monticello",
                        value => "America/Kentucky/Monticello"
                    },
                    {
                        label => "America/La_Paz",
                        value => "America/La_Paz"
                    },
                    {
                        label => "America/Lima",
                        value => "America/Lima"
                    },
                    {
                        label => "America/Los_Angeles",
                        value => "America/Los_Angeles"
                    },
                    {
                        label => "America/Maceio",
                        value => "America/Maceio"
                    },
                    {
                        label => "America/Managua",
                        value => "America/Managua"
                    },
                    {
                        label => "America/Manaus",
                        value => "America/Manaus"
                    },
                    {
                        label => "America/Martinique",
                        value => "America/Martinique"
                    },
                    {
                        label => "America/Matamoros",
                        value => "America/Matamoros"
                    },
                    {
                        label => "America/Mazatlan",
                        value => "America/Mazatlan"
                    },
                    {
                        label => "America/Menominee",
                        value => "America/Menominee"
                    },
                    {
                        label => "America/Merida",
                        value => "America/Merida"
                    },
                    {
                        label => "America/Metlakatla",
                        value => "America/Metlakatla"
                    },
                    {
                        label => "America/Mexico_City",
                        value => "America/Mexico_City"
                    },
                    {
                        label => "America/Miquelon",
                        value => "America/Miquelon"
                    },
                    {
                        label => "America/Moncton",
                        value => "America/Moncton"
                    },
                    {
                        label => "America/Monterrey",
                        value => "America/Monterrey"
                    },
                    {
                        label => "America/Montevideo",
                        value => "America/Montevideo"
                    },
                    {
                        label => "America/Nassau",
                        value => "America/Nassau"
                    },
                    {
                        label => "America/New_York",
                        value => "America/New_York"
                    },
                    {
                        label => "America/Nipigon",
                        value => "America/Nipigon"
                    },
                    {
                        label => "America/Nome",
                        value => "America/Nome"
                    },
                    {
                        label => "America/Noronha",
                        value => "America/Noronha"
                    },
                    {
                        label => "America/North_Dakota/Beulah",
                        value => "America/North_Dakota/Beulah"
                    },
                    {
                        label => "America/North_Dakota/Center",
                        value => "America/North_Dakota/Center"
                    },
                    {
                        label => "America/North_Dakota/New_Salem",
                        value => "America/North_Dakota/New_Salem"
                    },
                    {
                        label => "America/Ojinaga",
                        value => "America/Ojinaga"
                    },
                    {
                        label => "America/Panama",
                        value => "America/Panama"
                    },
                    {
                        label => "America/Pangnirtung",
                        value => "America/Pangnirtung"
                    },
                    {
                        label => "America/Paramaribo",
                        value => "America/Paramaribo"
                    },
                    {
                        label => "America/Phoenix",
                        value => "America/Phoenix"
                    },
                    {
                        label => "America/Port-au-Prince",
                        value => "America/Port-au-Prince"
                    },
                    {
                        label => "America/Port_of_Spain",
                        value => "America/Port_of_Spain"
                    },
                    {
                        label => "America/Porto_Velho",
                        value => "America/Porto_Velho"
                    },
                    {
                        label => "America/Puerto_Rico",
                        value => "America/Puerto_Rico"
                    },
                    {
                        label => "America/Punta_Arenas",
                        value => "America/Punta_Arenas"
                    },
                    {
                        label => "America/Rainy_River",
                        value => "America/Rainy_River"
                    },
                    {
                        label => "America/Rankin_Inlet",
                        value => "America/Rankin_Inlet"
                    },
                    {
                        label => "America/Recife",
                        value => "America/Recife"
                    },
                    {
                        label => "America/Regina",
                        value => "America/Regina"
                    },
                    {
                        label => "America/Resolute",
                        value => "America/Resolute"
                    },
                    {
                        label => "America/Rio_Branco",
                        value => "America/Rio_Branco"
                    },
                    {
                        label => "America/Santarem",
                        value => "America/Santarem"
                    },
                    {
                        label => "America/Santiago",
                        value => "America/Santiago"
                    },
                    {
                        label => "America/Santo_Domingo",
                        value => "America/Santo_Domingo"
                    },
                    {
                        label => "America/Sao_Paulo",
                        value => "America/Sao_Paulo"
                    },
                    {
                        label => "America/Scoresbysund",
                        value => "America/Scoresbysund"
                    },
                    {
                        label => "America/Sitka",
                        value => "America/Sitka"
                    },
                    {
                        label => "America/St_Johns",
                        value => "America/St_Johns"
                    },
                    {
                        label => "America/Swift_Current",
                        value => "America/Swift_Current"
                    },
                    {
                        label => "America/Tegucigalpa",
                        value => "America/Tegucigalpa"
                    },
                    {
                        label => "America/Thule",
                        value => "America/Thule"
                    },
                    {
                        label => "America/Thunder_Bay",
                        value => "America/Thunder_Bay"
                    },
                    {
                        label => "America/Tijuana",
                        value => "America/Tijuana"
                    },
                    {
                        label => "America/Toronto",
                        value => "America/Toronto"
                    },
                    {
                        label => "America/Vancouver",
                        value => "America/Vancouver"
                    },
                    {
                        label => "America/Whitehorse",
                        value => "America/Whitehorse"
                    },
                    {
                        label => "America/Winnipeg",
                        value => "America/Winnipeg"
                    },
                    {
                        label => "America/Yakutat",
                        value => "America/Yakutat"
                    },
                    {
                        label => "America/Yellowknife",
                        value => "America/Yellowknife"
                    },
                    {
                        label => "Antarctica/Casey",
                        value => "Antarctica/Casey"
                    },
                    {
                        label => "Antarctica/Davis",
                        value => "Antarctica/Davis"
                    },
                    {
                        label => "Antarctica/DumontDUrville",
                        value => "Antarctica/DumontDUrville"
                    },
                    {
                        label => "Antarctica/Macquarie",
                        value => "Antarctica/Macquarie"
                    },
                    {
                        label => "Antarctica/Mawson",
                        value => "Antarctica/Mawson"
                    },
                    {
                        label => "Antarctica/Palmer",
                        value => "Antarctica/Palmer"
                    },
                    {
                        label => "Antarctica/Rothera",
                        value => "Antarctica/Rothera"
                    },
                    {
                        label => "Antarctica/Syowa",
                        value => "Antarctica/Syowa"
                    },
                    {
                        label => "Antarctica/Troll",
                        value => "Antarctica/Troll"
                    },
                    {
                        label => "Antarctica/Vostok",
                        value => "Antarctica/Vostok"
                    },
                    {
                        label => "Asia/Almaty",
                        value => "Asia/Almaty"
                    },
                    {
                        label => "Asia/Amman",
                        value => "Asia/Amman"
                    },
                    {
                        label => "Asia/Anadyr",
                        value => "Asia/Anadyr"
                    },
                    {
                        label => "Asia/Aqtau",
                        value => "Asia/Aqtau"
                    },
                    {
                        label => "Asia/Aqtobe",
                        value => "Asia/Aqtobe"
                    },
                    {
                        label => "Asia/Ashgabat",
                        value => "Asia/Ashgabat"
                    },
                    {
                        label => "Asia/Atyrau",
                        value => "Asia/Atyrau"
                    },
                    {
                        label => "Asia/Baghdad",
                        value => "Asia/Baghdad"
                    },
                    {
                        label => "Asia/Baku",
                        value => "Asia/Baku"
                    },
                    {
                        label => "Asia/Bangkok",
                        value => "Asia/Bangkok"
                    },
                    {
                        label => "Asia/Barnaul",
                        value => "Asia/Barnaul"
                    },
                    {
                        label => "Asia/Beirut",
                        value => "Asia/Beirut"
                    },
                    {
                        label => "Asia/Bishkek",
                        value => "Asia/Bishkek"
                    },
                    {
                        label => "Asia/Brunei",
                        value => "Asia/Brunei"
                    },
                    {
                        label => "Asia/Chita",
                        value => "Asia/Chita"
                    },
                    {
                        label => "Asia/Choibalsan",
                        value => "Asia/Choibalsan"
                    },
                    {
                        label => "Asia/Colombo",
                        value => "Asia/Colombo"
                    },
                    {
                        label => "Asia/Damascus",
                        value => "Asia/Damascus"
                    },
                    {
                        label => "Asia/Dhaka",
                        value => "Asia/Dhaka"
                    },
                    {
                        label => "Asia/Dili",
                        value => "Asia/Dili"
                    },
                    {
                        label => "Asia/Dubai",
                        value => "Asia/Dubai"
                    },
                    {
                        label => "Asia/Dushanbe",
                        value => "Asia/Dushanbe"
                    },
                    {
                        label => "Asia/Famagusta",
                        value => "Asia/Famagusta"
                    },
                    {
                        label => "Asia/Gaza",
                        value => "Asia/Gaza"
                    },
                    {
                        label => "Asia/Hebron",
                        value => "Asia/Hebron"
                    },
                    {
                        label => "Asia/Ho_Chi_Minh",
                        value => "Asia/Ho_Chi_Minh"
                    },
                    {
                        label => "Asia/Hong_Kong",
                        value => "Asia/Hong_Kong"
                    },
                    {
                        label => "Asia/Hovd",
                        value => "Asia/Hovd"
                    },
                    {
                        label => "Asia/Irkutsk",
                        value => "Asia/Irkutsk"
                    },
                    {
                        label => "Asia/Jakarta",
                        value => "Asia/Jakarta"
                    },
                    {
                        label => "Asia/Jayapura",
                        value => "Asia/Jayapura"
                    },
                    {
                        label => "Asia/Jerusalem",
                        value => "Asia/Jerusalem"
                    },
                    {
                        label => "Asia/Kabul",
                        value => "Asia/Kabul"
                    },
                    {
                        label => "Asia/Kamchatka",
                        value => "Asia/Kamchatka"
                    },
                    {
                        label => "Asia/Karachi",
                        value => "Asia/Karachi"
                    },
                    {
                        label => "Asia/Kathmandu",
                        value => "Asia/Kathmandu"
                    },
                    {
                        label => "Asia/Khandyga",
                        value => "Asia/Khandyga"
                    },
                    {
                        label => "Asia/Kolkata",
                        value => "Asia/Kolkata"
                    },
                    {
                        label => "Asia/Krasnoyarsk",
                        value => "Asia/Krasnoyarsk"
                    },
                    {
                        label => "Asia/Kuala_Lumpur",
                        value => "Asia/Kuala_Lumpur"
                    },
                    {
                        label => "Asia/Kuching",
                        value => "Asia/Kuching"
                    },
                    {
                        label => "Asia/Macau",
                        value => "Asia/Macau"
                    },
                    {
                        label => "Asia/Magadan",
                        value => "Asia/Magadan"
                    },
                    {
                        label => "Asia/Makassar",
                        value => "Asia/Makassar"
                    },
                    {
                        label => "Asia/Manila",
                        value => "Asia/Manila"
                    },
                    {
                        label => "Asia/Nicosia",
                        value => "Asia/Nicosia"
                    },
                    {
                        label => "Asia/Novokuznetsk",
                        value => "Asia/Novokuznetsk"
                    },
                    {
                        label => "Asia/Novosibirsk",
                        value => "Asia/Novosibirsk"
                    },
                    {
                        label => "Asia/Omsk",
                        value => "Asia/Omsk"
                    },
                    {
                        label => "Asia/Oral",
                        value => "Asia/Oral"
                    },
                    {
                        label => "Asia/Pontianak",
                        value => "Asia/Pontianak"
                    },
                    {
                        label => "Asia/Pyongyang",
                        value => "Asia/Pyongyang"
                    },
                    {
                        label => "Asia/Qatar",
                        value => "Asia/Qatar"
                    },
                    {
                        label => "Asia/Qyzylorda",
                        value => "Asia/Qyzylorda"
                    },
                    {
                        label => "Asia/Riyadh",
                        value => "Asia/Riyadh"
                    },
                    {
                        label => "Asia/Sakhalin",
                        value => "Asia/Sakhalin"
                    },
                    {
                        label => "Asia/Samarkand",
                        value => "Asia/Samarkand"
                    },
                    {
                        label => "Asia/Seoul",
                        value => "Asia/Seoul"
                    },
                    {
                        label => "Asia/Shanghai",
                        value => "Asia/Shanghai"
                    },
                    {
                        label => "Asia/Singapore",
                        value => "Asia/Singapore"
                    },
                    {
                        label => "Asia/Srednekolymsk",
                        value => "Asia/Srednekolymsk"
                    },
                    {
                        label => "Asia/Taipei",
                        value => "Asia/Taipei"
                    },
                    {
                        label => "Asia/Tashkent",
                        value => "Asia/Tashkent"
                    },
                    {
                        label => "Asia/Tbilisi",
                        value => "Asia/Tbilisi"
                    },
                    {
                        label => "Asia/Tehran",
                        value => "Asia/Tehran"
                    },
                    {
                        label => "Asia/Thimphu",
                        value => "Asia/Thimphu"
                    },
                    {
                        label => "Asia/Tokyo",
                        value => "Asia/Tokyo"
                    },
                    {
                        label => "Asia/Tomsk",
                        value => "Asia/Tomsk"
                    },
                    {
                        label => "Asia/Ulaanbaatar",
                        value => "Asia/Ulaanbaatar"
                    },
                    {
                        label => "Asia/Urumqi",
                        value => "Asia/Urumqi"
                    },
                    {
                        label => "Asia/Ust-Nera",
                        value => "Asia/Ust-Nera"
                    },
                    {
                        label => "Asia/Vladivostok",
                        value => "Asia/Vladivostok"
                    },
                    {
                        label => "Asia/Yakutsk",
                        value => "Asia/Yakutsk"
                    },
                    {
                        label => "Asia/Yangon",
                        value => "Asia/Yangon"
                    },
                    {
                        label => "Asia/Yekaterinburg",
                        value => "Asia/Yekaterinburg"
                    },
                    {
                        label => "Asia/Yerevan",
                        value => "Asia/Yerevan"
                    },
                    {
                        label => "Atlantic/Azores",
                        value => "Atlantic/Azores"
                    },
                    {
                        label => "Atlantic/Bermuda",
                        value => "Atlantic/Bermuda"
                    },
                    {
                        label => "Atlantic/Canary",
                        value => "Atlantic/Canary"
                    },
                    {
                        label => "Atlantic/Cape_Verde",
                        value => "Atlantic/Cape_Verde"
                    },
                    {
                        label => "Atlantic/Faroe",
                        value => "Atlantic/Faroe"
                    },
                    {
                        label => "Atlantic/Madeira",
                        value => "Atlantic/Madeira"
                    },
                    {
                        label => "Atlantic/Reykjavik",
                        value => "Atlantic/Reykjavik"
                    },
                    {
                        label => "Atlantic/South_Georgia",
                        value => "Atlantic/South_Georgia"
                    },
                    {
                        label => "Atlantic/Stanley",
                        value => "Atlantic/Stanley"
                    },
                    {
                        label => "Australia/Adelaide",
                        value => "Australia/Adelaide"
                    },
                    {
                        label => "Australia/Brisbane",
                        value => "Australia/Brisbane"
                    },
                    {
                        label => "Australia/Broken_Hill",
                        value => "Australia/Broken_Hill"
                    },
                    {
                        label => "Australia/Currie",
                        value => "Australia/Currie"
                    },
                    {
                        label => "Australia/Darwin",
                        value => "Australia/Darwin"
                    },
                    {
                        label => "Australia/Eucla",
                        value => "Australia/Eucla"
                    },
                    {
                        label => "Australia/Hobart",
                        value => "Australia/Hobart"
                    },
                    {
                        label => "Australia/Lindeman",
                        value => "Australia/Lindeman"
                    },
                    {
                        label => "Australia/Lord_Howe",
                        value => "Australia/Lord_Howe"
                    },
                    {
                        label => "Australia/Melbourne",
                        value => "Australia/Melbourne"
                    },
                    {
                        label => "Australia/Perth",
                        value => "Australia/Perth"
                    },
                    {
                        label => "Australia/Sydney",
                        value => "Australia/Sydney"
                    },
                    {
                        label => "Europe/Amsterdam",
                        value => "Europe/Amsterdam"
                    },
                    {
                        label => "Europe/Andorra",
                        value => "Europe/Andorra"
                    },
                    {
                        label => "Europe/Astrakhan",
                        value => "Europe/Astrakhan"
                    },
                    {
                        label => "Europe/Athens",
                        value => "Europe/Athens"
                    },
                    {
                        label => "Europe/Belgrade",
                        value => "Europe/Belgrade"
                    },
                    {
                        label => "Europe/Berlin",
                        value => "Europe/Berlin"
                    },
                    {
                        label => "Europe/Brussels",
                        value => "Europe/Brussels"
                    },
                    {
                        label => "Europe/Bucharest",
                        value => "Europe/Bucharest"
                    },
                    {
                        label => "Europe/Budapest",
                        value => "Europe/Budapest"
                    },
                    {
                        label => "Europe/Chisinau",
                        value => "Europe/Chisinau"
                    },
                    {
                        label => "Europe/Copenhagen",
                        value => "Europe/Copenhagen"
                    },
                    {
                        label => "Europe/Dublin",
                        value => "Europe/Dublin"
                    },
                    {
                        label => "Europe/Gibraltar",
                        value => "Europe/Gibraltar"
                    },
                    {
                        label => "Europe/Helsinki",
                        value => "Europe/Helsinki"
                    },
                    {
                        label => "Europe/Istanbul",
                        value => "Europe/Istanbul"
                    },
                    {
                        label => "Europe/Kaliningrad",
                        value => "Europe/Kaliningrad"
                    },
                    {
                        label => "Europe/Kiev",
                        value => "Europe/Kiev"
                    },
                    {
                        label => "Europe/Kirov",
                        value => "Europe/Kirov"
                    },
                    {
                        label => "Europe/Lisbon",
                        value => "Europe/Lisbon"
                    },
                    {
                        label => "Europe/London",
                        value => "Europe/London"
                    },
                    {
                        label => "Europe/Luxembourg",
                        value => "Europe/Luxembourg"
                    },
                    {
                        label => "Europe/Madrid",
                        value => "Europe/Madrid"
                    },
                    {
                        label => "Europe/Malta",
                        value => "Europe/Malta"
                    },
                    {
                        label => "Europe/Minsk",
                        value => "Europe/Minsk"
                    },
                    {
                        label => "Europe/Monaco",
                        value => "Europe/Monaco"
                    },
                    {
                        label => "Europe/Moscow",
                        value => "Europe/Moscow"
                    },
                    {
                        label => "Europe/Oslo",
                        value => "Europe/Oslo"
                    },
                    {
                        label => "Europe/Paris",
                        value => "Europe/Paris"
                    },
                    {
                        label => "Europe/Prague",
                        value => "Europe/Prague"
                    },
                    {
                        label => "Europe/Riga",
                        value => "Europe/Riga"
                    },
                    {
                        label => "Europe/Rome",
                        value => "Europe/Rome"
                    },
                    {
                        label => "Europe/Samara",
                        value => "Europe/Samara"
                    },
                    {
                        label => "Europe/Saratov",
                        value => "Europe/Saratov"
                    },
                    {
                        label => "Europe/Simferopol",
                        value => "Europe/Simferopol"
                    },
                    {
                        label => "Europe/Sofia",
                        value => "Europe/Sofia"
                    },
                    {
                        label => "Europe/Stockholm",
                        value => "Europe/Stockholm"
                    },
                    {
                        label => "Europe/Tallinn",
                        value => "Europe/Tallinn"
                    },
                    {
                        label => "Europe/Tirane",
                        value => "Europe/Tirane"
                    },
                    {
                        label => "Europe/Ulyanovsk",
                        value => "Europe/Ulyanovsk"
                    },
                    {
                        label => "Europe/Uzhgorod",
                        value => "Europe/Uzhgorod"
                    },
                    {
                        label => "Europe/Vienna",
                        value => "Europe/Vienna"
                    },
                    {
                        label => "Europe/Vilnius",
                        value => "Europe/Vilnius"
                    },
                    {
                        label => "Europe/Volgograd",
                        value => "Europe/Volgograd"
                    },
                    {
                        label => "Europe/Warsaw",
                        value => "Europe/Warsaw"
                    },
                    {
                        label => "Europe/Zaporozhye",
                        value => "Europe/Zaporozhye"
                    },
                    {
                        label => "Europe/Zurich",
                        value => "Europe/Zurich"
                    },
                    {
                        label => "Indian/Chagos",
                        value => "Indian/Chagos"
                    },
                    {
                        label => "Indian/Christmas",
                        value => "Indian/Christmas"
                    },
                    {
                        label => "Indian/Cocos",
                        value => "Indian/Cocos"
                    },
                    {
                        label => "Indian/Kerguelen",
                        value => "Indian/Kerguelen"
                    },
                    {
                        label => "Indian/Mahe",
                        value => "Indian/Mahe"
                    },
                    {
                        label => "Indian/Maldives",
                        value => "Indian/Maldives"
                    },
                    {
                        label => "Indian/Mauritius",
                        value => "Indian/Mauritius"
                    },
                    {
                        label => "Indian/Reunion",
                        value => "Indian/Reunion"
                    },
                    {
                        label => "Pacific/Apia",
                        value => "Pacific/Apia"
                    },
                    {
                        label => "Pacific/Auckland",
                        value => "Pacific/Auckland"
                    },
                    {
                        label => "Pacific/Bougainville",
                        value => "Pacific/Bougainville"
                    },
                    {
                        label => "Pacific/Chatham",
                        value => "Pacific/Chatham"
                    },
                    {
                        label => "Pacific/Chuuk",
                        value => "Pacific/Chuuk"
                    },
                    {
                        label => "Pacific/Easter",
                        value => "Pacific/Easter"
                    },
                    {
                        label => "Pacific/Efate",
                        value => "Pacific/Efate"
                    },
                    {
                        label => "Pacific/Enderbury",
                        value => "Pacific/Enderbury"
                    },
                    {
                        label => "Pacific/Fakaofo",
                        value => "Pacific/Fakaofo"
                    },
                    {
                        label => "Pacific/Fiji",
                        value => "Pacific/Fiji"
                    },
                    {
                        label => "Pacific/Funafuti",
                        value => "Pacific/Funafuti"
                    },
                    {
                        label => "Pacific/Galapagos",
                        value => "Pacific/Galapagos"
                    },
                    {
                        label => "Pacific/Gambier",
                        value => "Pacific/Gambier"
                    },
                    {
                        label => "Pacific/Guadalcanal",
                        value => "Pacific/Guadalcanal"
                    },
                    {
                        label => "Pacific/Guam",
                        value => "Pacific/Guam"
                    },
                    {
                        label => "Pacific/Honolulu",
                        value => "Pacific/Honolulu"
                    },
                    {
                        label => "Pacific/Kiritimati",
                        value => "Pacific/Kiritimati"
                    },
                    {
                        label => "Pacific/Kosrae",
                        value => "Pacific/Kosrae"
                    },
                    {
                        label => "Pacific/Kwajalein",
                        value => "Pacific/Kwajalein"
                    },
                    {
                        label => "Pacific/Majuro",
                        value => "Pacific/Majuro"
                    },
                    {
                        label => "Pacific/Marquesas",
                        value => "Pacific/Marquesas"
                    },
                    {
                        label => "Pacific/Nauru",
                        value => "Pacific/Nauru"
                    },
                    {
                        label => "Pacific/Niue",
                        value => "Pacific/Niue"
                    },
                    {
                        label => "Pacific/Norfolk",
                        value => "Pacific/Norfolk"
                    },
                    {
                        label => "Pacific/Noumea",
                        value => "Pacific/Noumea"
                    },
                    {
                        label => "Pacific/Pago_Pago",
                        value => "Pacific/Pago_Pago"
                    },
                    {
                        label => "Pacific/Palau",
                        value => "Pacific/Palau"
                    },
                    {
                        label => "Pacific/Pitcairn",
                        value => "Pacific/Pitcairn"
                    },
                    {
                        label => "Pacific/Pohnpei",
                        value => "Pacific/Pohnpei"
                    },
                    {
                        label => "Pacific/Port_Moresby",
                        value => "Pacific/Port_Moresby"
                    },
                    {
                        label => "Pacific/Rarotonga",
                        value => "Pacific/Rarotonga"
                    },
                    {
                        label => "Pacific/Tahiti",
                        value => "Pacific/Tahiti"
                    },
                    {
                        label => "Pacific/Tarawa",
                        value => "Pacific/Tarawa"
                    },
                    {
                        label => "Pacific/Tongatapu",
                        value => "Pacific/Tongatapu"
                    },
                    {
                        label => "Pacific/Wake",
                        value => "Pacific/Wake"
                    },
                    {
                        label => "Pacific/Wallis",
                        value => "Pacific/Wallis"
                    }
                ],
                default     => undef,
                placeholder => undef,
                required    => $false,
                type        => "string"
            }
        },
        placeholders => {
            dhcpservers => "127.0.0.1",
            domain      => "packetfence.org",
            hostname    => "packetfence",
            timezone    => ""
        },
        status => 200
    }
);

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


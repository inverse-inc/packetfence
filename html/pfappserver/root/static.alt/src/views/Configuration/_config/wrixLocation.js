import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasWRIXLocations,
  WRIXLocationExists
} from '@/globals/pfValidators'
import {
  maxLength,
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: 'WRIX Identifier', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const fields = [
  {
    value: 'id',
    text: i18n.t('WRIX Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'wrixLocation', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by WRIX Identifier'),
    searchableOptions: {
      searchApiEndpoint: 'wrix_locations',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'wrixLocations' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: quickCondition }
          ]
        }]
      }
    }
  }
}

export const view = (_, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return [
    {
      tab: i18n.t('Identification'),
      rows: [
        {
          label: i18n.t('Id'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              }
            }
          ]
        },
        {
          label: i18n.t('Provider Identifier'),
          cols: [
            {
              namespace: 'Provider_Identifier',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Location Identifier'),
          cols: [
            {
              namespace: 'Location_Identifier',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Service Provider Brand'),
          cols: [
            {
              namespace: 'Service_Provider_Brand',
              component: pfFormInput
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Location'),
      rows: [
        {
          label: i18n.t('Location Type'),
          cols: [
            {
              namespace: 'Location_Type',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Sub Location Type'),
          cols: [
            {
              namespace: 'Sub_Location_Type',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('English Location Name'),
          cols: [
            {
              namespace: 'English_Location_Name',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Location Address 1'),
          cols: [
            {
              namespace: 'Location_Address1',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Location Address 2'),
          cols: [
            {
              namespace: 'Location_Address2',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('English Location City'),
          cols: [
            {
              namespace: 'English_Location_City',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Location Zip Postal Code'),
          cols: [
            {
              namespace: 'Location_Zip_Postal_Code',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Location State Province Name'),
          cols: [
            {
              namespace: 'Location_State_Province_Name',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Location Country Name'),
          cols: [
            {
              namespace: 'Location_Country_Name',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Location Phone Number'),
          cols: [
            {
              namespace: 'Location_Phone_Number',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Location URL'),
          cols: [
            {
              namespace: 'Location_URL',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Coverage Area'),
          cols: [
            {
              namespace: 'Coverage_Area',
              component: pfFormInput
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('SSID'),
      rows: [
        {
          label: i18n.t('SSID Open Auth'),
          cols: [
            {
              namespace: 'SSID_Open_Auth',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('SSID Broadcasted'),
          cols: [
            {
              namespace: 'SSID_Broadcasted',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          label: i18n.t('WEP Key'),
          cols: [
            {
              namespace: 'WEP_Key',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('WEP Key Entry Method'),
          cols: [
            {
              namespace: 'WEP_Key_Entry_Method',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('WEP Key Size'),
          cols: [
            {
              namespace: 'WEP_Key_Size',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('SSID 1X'),
          cols: [
            {
              namespace: 'SSID_1X',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('SSID 1X Broadcasted'),
          cols: [
            {
              namespace: 'SSID_1X_Broadcasted',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          label: i18n.t('Security Protocol 1X'),
          cols: [
            {
              namespace: 'Security_Protocol_1X',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to add a protocol'),
                trackBy: 'value',
                label: 'text',
                options: [
                  { value: 'NONE', text: 'None' },
                  { value: 'WPA-Enterprise', text: 'WPA Enterprise' },
                  { value: 'WPA2', text: 'WPA2' },
                  { value: 'EAP-PEAP', text: 'EAP PEAP' },
                  { value: 'EAP-TTLS', text: 'EAP TTLS' },
                  { value: 'EAP_SIM', text: 'EAP SIM' },
                  { value: 'EAP-AKA', text: 'EAP AKA' }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Restricted Access'),
          cols: [
            {
              namespace: 'Restricted_Access',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          label: i18n.t('Client Support'),
          cols: [
            {
              namespace: 'Client_Support',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('MAC Address'),
          cols: [
            {
              namespace: 'MAC_Address',
              component: pfFormInput
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Hours'),
      rows: [
        {
          label: i18n.t('UTC Timezone'),
          cols: [
            {
              namespace: 'UTC_Timezone',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to add a timezone'),
                trackBy: 'value',
                label: 'text',
                groupLabel: 'group',
                groupValues: 'items',
                options: [
                  {
                    group: 'Africa',
                    items: [
                      { value: 'Africa/Abidjan', text: 'Abidjan' },
                      { value: 'Africa/Accra', text: 'Accra' },
                      { value: 'Africa/Algiers', text: 'Algiers' },
                      { value: 'Africa/Bissau', text: 'Bissau' },
                      { value: 'Africa/Cairo', text: 'Cairo' },
                      { value: 'Africa/Casablanca', text: 'Casablanca' },
                      { value: 'Africa/Ceuta', text: 'Ceuta' },
                      { value: 'Africa/El_Aaiun', text: 'El_Aaiun' },
                      { value: 'Africa/Johannesburg', text: 'Johannesburg' },
                      { value: 'Africa/Khartoum', text: 'Khartoum' },
                      { value: 'Africa/Lagos', text: 'Lagos' },
                      { value: 'Africa/Maputo', text: 'Maputo' },
                      { value: 'Africa/Monrovia', text: 'Monrovia' },
                      { value: 'Africa/Nairobi', text: 'Nairobi' },
                      { value: 'Africa/Ndjamena', text: 'Ndjamena' },
                      { value: 'Africa/Tripoli', text: 'Tripoli' },
                      { value: 'Africa/Tunis', text: 'Tunis' },
                      { value: 'Africa/Windhoek', text: 'Windhoek' }
                    ]
                  },
                  {
                    group: 'America',
                    items: [
                      { value: 'America/Adak', text: 'Adak' },
                      { value: 'America/Anchorage', text: 'Anchorage' },
                      { value: 'America/Araguaina', text: 'Araguaina' },
                      { value: 'America/Argentina/Buenos_Aires', text: 'Argentina/Buenos_Aires' },
                      { value: 'America/Argentina/Catamarca', text: 'Argentina/Catamarca' },
                      { value: 'America/Argentina/Cordoba', text: 'Argentina/Cordoba' },
                      { value: 'America/Argentina/Jujuy', text: 'Argentina/Jujuy' },
                      { value: 'America/Argentina/La_Rioja', text: 'Argentina/La_Rioja' },
                      { value: 'America/Argentina/Mendoza', text: 'Argentina/Mendoza' },
                      { value: 'America/Argentina/Rio_Gallegos', text: 'Argentina/Rio_Gallegos' },
                      { value: 'America/Argentina/Salta', text: 'Argentina/Salta' },
                      { value: 'America/Argentina/San_Juan', text: 'Argentina/San_Juan' },
                      { value: 'America/Argentina/San_Luis', text: 'Argentina/San_Luis' },
                      { value: 'America/Argentina/Tucuman', text: 'Argentina/Tucuman' },
                      { value: 'America/Argentina/Ushuaia', text: 'Argentina/Ushuaia' },
                      { value: 'America/Asuncion', text: 'Asuncion' },
                      { value: 'America/Atikokan', text: 'Atikokan' },
                      { value: 'America/Bahia', text: 'Bahia' },
                      { value: 'America/Bahia_Banderas', text: 'Bahia_Banderas' },
                      { value: 'America/Barbados', text: 'Barbados' },
                      { value: 'America/Belem', text: 'Belem' },
                      { value: 'America/Belize', text: 'Belize' },
                      { value: 'America/Blanc-Sablon', text: 'Blanc-Sablon' },
                      { value: 'America/Boa_Vista', text: 'Boa_Vista' },
                      { value: 'America/Bogota', text: 'Bogota' },
                      { value: 'America/Boise', text: 'Boise' },
                      { value: 'America/Cambridge_Bay', text: 'Cambridge_Bay' },
                      { value: 'America/Campo_Grande', text: 'Campo_Grande' },
                      { value: 'America/Cancun', text: 'Cancun' },
                      { value: 'America/Caracas', text: 'Caracas' },
                      { value: 'America/Cayenne', text: 'Cayenne' },
                      { value: 'America/Chicago', text: 'Chicago' },
                      { value: 'America/Chihuahua', text: 'Chihuahua' },
                      { value: 'America/Costa_Rica', text: 'Costa_Rica' },
                      { value: 'America/Creston', text: 'Creston' },
                      { value: 'America/Cuiaba', text: 'Cuiaba' },
                      { value: 'America/Curacao', text: 'Curacao' },
                      { value: 'America/Danmarkshavn', text: 'Danmarkshavn' },
                      { value: 'America/Dawson', text: 'Dawson' },
                      { value: 'America/Dawson_Creek', text: 'Dawson_Creek' },
                      { value: 'America/Denver', text: 'Denver' },
                      { value: 'America/Detroit', text: 'Detroit' },
                      { value: 'America/Edmonton', text: 'Edmonton' },
                      { value: 'America/Eirunepe', text: 'Eirunepe' },
                      { value: 'America/El_Salvador', text: 'El_Salvador' },
                      { value: 'America/Fort_Nelson', text: 'Fort_Nelson' },
                      { value: 'America/Fortaleza', text: 'Fortaleza' },
                      { value: 'America/Glace_Bay', text: 'Glace_Bay' },
                      { value: 'America/Godthab', text: 'Godthab' },
                      { value: 'America/Goose_Bay', text: 'Goose_Bay' },
                      { value: 'America/Grand_Turk', text: 'Grand_Turk' },
                      { value: 'America/Guatemala', text: 'Guatemala' },
                      { value: 'America/Guayaquil', text: 'Guayaquil' },
                      { value: 'America/Guyana', text: 'Guyana' },
                      { value: 'America/Halifax', text: 'Halifax' },
                      { value: 'America/Havana', text: 'Havana' },
                      { value: 'America/Hermosillo', text: 'Hermosillo' },
                      { value: 'America/Indiana/Indianapolis', text: 'Indiana/Indianapolis' },
                      { value: 'America/Indiana/Knox', text: 'Indiana/Knox' },
                      { value: 'America/Indiana/Marengo', text: 'Indiana/Marengo' },
                      { value: 'America/Indiana/Petersburg', text: 'Indiana/Petersburg' },
                      { value: 'America/Indiana/Tell_City', text: 'Indiana/Tell_City' },
                      { value: 'America/Indiana/Vevay', text: 'Indiana/Vevay' },
                      { value: 'America/Indiana/Vincennes', text: 'Indiana/Vincennes' },
                      { value: 'America/Indiana/Winamac', text: 'Indiana/Winamac' },
                      { value: 'America/Inuvik', text: 'Inuvik' },
                      { value: 'America/Iqaluit', text: 'Iqaluit' },
                      { value: 'America/Jamaica', text: 'Jamaica' },
                      { value: 'America/Juneau', text: 'Juneau' },
                      { value: 'America/Kentucky/Louisville', text: 'Kentucky/Louisville' },
                      { value: 'America/Kentucky/Monticello', text: 'Kentucky/Monticello' },
                      { value: 'America/La_Paz', text: 'La_Paz' },
                      { value: 'America/Lima', text: 'Lima' },
                      { value: 'America/Los_Angeles', text: 'Los_Angeles' },
                      { value: 'America/Maceio', text: 'Maceio' },
                      { value: 'America/Managua', text: 'Managua' },
                      { value: 'America/Manaus', text: 'Manaus' },
                      { value: 'America/Martinique', text: 'Martinique' },
                      { value: 'America/Matamoros', text: 'Matamoros' },
                      { value: 'America/Mazatlan', text: 'Mazatlan' },
                      { value: 'America/Menominee', text: 'Menominee' },
                      { value: 'America/Merida', text: 'Merida' },
                      { value: 'America/Metlakatla', text: 'Metlakatla' },
                      { value: 'America/Mexico_City', text: 'Mexico_City' },
                      { value: 'America/Miquelon', text: 'Miquelon' },
                      { value: 'America/Moncton', text: 'Moncton' },
                      { value: 'America/Monterrey', text: 'Monterrey' },
                      { value: 'America/Montevideo', text: 'Montevideo' },
                      { value: 'America/Nassau', text: 'Nassau' },
                      { value: 'America/New_York', text: 'New_York' },
                      { value: 'America/Nipigon', text: 'Nipigon' },
                      { value: 'America/Nome', text: 'Nome' },
                      { value: 'America/Noronha', text: 'Noronha' },
                      { value: 'America/North_Dakota/Beulah', text: 'North_Dakota/Beulah' },
                      { value: 'America/North_Dakota/Center', text: 'North_Dakota/Center' },
                      { value: 'America/North_Dakota/New_Salem', text: 'North_Dakota/New_Salem' },
                      { value: 'America/Ojinaga', text: 'Ojinaga' },
                      { value: 'America/Panama', text: 'Panama' },
                      { value: 'America/Pangnirtung', text: 'Pangnirtung' },
                      { value: 'America/Paramaribo', text: 'Paramaribo' },
                      { value: 'America/Phoenix', text: 'Phoenix' },
                      { value: 'America/Port-au-Prince', text: 'Port-au-Prince' },
                      { value: 'America/Port_of_Spain', text: 'Port_of_Spain' },
                      { value: 'America/Porto_Velho', text: 'Porto_Velho' },
                      { value: 'America/Puerto_Rico', text: 'Puerto_Rico' },
                      { value: 'America/Punta_Arenas', text: 'Punta_Arenas' },
                      { value: 'America/Rainy_River', text: 'Rainy_River' },
                      { value: 'America/Rankin_Inlet', text: 'Rankin_Inlet' },
                      { value: 'America/Recife', text: 'Recife' },
                      { value: 'America/Regina', text: 'Regina' },
                      { value: 'America/Resolute', text: 'Resolute' },
                      { value: 'America/Rio_Branco', text: 'Rio_Branco' },
                      { value: 'America/Santarem', text: 'Santarem' },
                      { value: 'America/Santiago', text: 'Santiago' },
                      { value: 'America/Santo_Domingo', text: 'Santo_Domingo' },
                      { value: 'America/Sao_Paulo', text: 'Sao_Paulo' },
                      { value: 'America/Scoresbysund', text: 'Scoresbysund' },
                      { value: 'America/Sitka', text: 'Sitka' },
                      { value: 'America/St_Johns', text: 'St_Johns' },
                      { value: 'America/Swift_Current', text: 'Swift_Current' },
                      { value: 'America/Tegucigalpa', text: 'Tegucigalpa' },
                      { value: 'America/Thule', text: 'Thule' },
                      { value: 'America/Thunder_Bay', text: 'Thunder_Bay' },
                      { value: 'America/Tijuana', text: 'Tijuana' },
                      { value: 'America/Toronto', text: 'Toronto' },
                      { value: 'America/Vancouver', text: 'Vancouver' },
                      { value: 'America/Whitehorse', text: 'Whitehorse' },
                      { value: 'America/Winnipeg', text: 'Winnipeg' },
                      { value: 'America/Yakutat', text: 'Yakutat' },
                      { value: 'America/Yellowknife', text: 'Yellowknife' }
                    ]
                  },
                  {
                    group: 'Antarctica',
                    items: [
                      { value: 'Antarctica/Casey', text: 'Casey' },
                      { value: 'Antarctica/Davis', text: 'Davis' },
                      { value: 'Antarctica/DumontDUrville', text: 'DumontDUrville' },
                      { value: 'Antarctica/Macquarie', text: 'Macquarie' },
                      { value: 'Antarctica/Mawson', text: 'Mawson' },
                      { value: 'Antarctica/Palmer', text: 'Palmer' },
                      { value: 'Antarctica/Rothera', text: 'Rothera' },
                      { value: 'Antarctica/Syowa', text: 'Syowa' },
                      { value: 'Antarctica/Troll', text: 'Troll' },
                      { value: 'Antarctica/Vostok', text: 'Vostok' }
                    ]
                  },
                  {
                    group: 'Asia',
                    items: [
                      { value: 'Asia/Almaty', text: 'Almaty' },
                      { value: 'Asia/Amman', text: 'Amman' },
                      { value: 'Asia/Anadyr', text: 'Anadyr' },
                      { value: 'Asia/Aqtau', text: 'Aqtau' },
                      { value: 'Asia/Aqtobe', text: 'Aqtobe' },
                      { value: 'Asia/Ashgabat', text: 'Ashgabat' },
                      { value: 'Asia/Atyrau', text: 'Atyrau' },
                      { value: 'Asia/Baghdad', text: 'Baghdad' },
                      { value: 'Asia/Baku', text: 'Baku' },
                      { value: 'Asia/Bangkok', text: 'Bangkok' },
                      { value: 'Asia/Barnaul', text: 'Barnaul' },
                      { value: 'Asia/Beirut', text: 'Beirut' },
                      { value: 'Asia/Bishkek', text: 'Bishkek' },
                      { value: 'Asia/Brunei', text: 'Brunei' },
                      { value: 'Asia/Chita', text: 'Chita' },
                      { value: 'Asia/Choibalsan', text: 'Choibalsan' },
                      { value: 'Asia/Colombo', text: 'Colombo' },
                      { value: 'Asia/Damascus', text: 'Damascus' },
                      { value: 'Asia/Dhaka', text: 'Dhaka' },
                      { value: 'Asia/Dili', text: 'Dili' },
                      { value: 'Asia/Dubai', text: 'Dubai' },
                      { value: 'Asia/Dushanbe', text: 'Dushanbe' },
                      { value: 'Asia/Famagusta', text: 'Famagusta' },
                      { value: 'Asia/Gaza', text: 'Gaza' },
                      { value: 'Asia/Hebron', text: 'Hebron' },
                      { value: 'Asia/Ho_Chi_Minh', text: 'Ho_Chi_Minh' },
                      { value: 'Asia/Hong_Kong', text: 'Hong_Kong' },
                      { value: 'Asia/Hovd', text: 'Hovd' },
                      { value: 'Asia/Irkutsk', text: 'Irkutsk' },
                      { value: 'Asia/Jakarta', text: 'Jakarta' },
                      { value: 'Asia/Jayapura', text: 'Jayapura' },
                      { value: 'Asia/Jerusalem', text: 'Jerusalem' },
                      { value: 'Asia/Kabul', text: 'Kabul' },
                      { value: 'Asia/Kamchatka', text: 'Kamchatka' },
                      { value: 'Asia/Karachi', text: 'Karachi' },
                      { value: 'Asia/Kathmandu', text: 'Kathmandu' },
                      { value: 'Asia/Khandyga', text: 'Khandyga' },
                      { value: 'Asia/Kolkata', text: 'Kolkata' },
                      { value: 'Asia/Krasnoyarsk', text: 'Krasnoyarsk' },
                      { value: 'Asia/Kuala_Lumpur', text: 'Kuala_Lumpur' },
                      { value: 'Asia/Kuching', text: 'Kuching' },
                      { value: 'Asia/Macau', text: 'Macau' },
                      { value: 'Asia/Magadan', text: 'Magadan' },
                      { value: 'Asia/Makassar', text: 'Makassar' },
                      { value: 'Asia/Manila', text: 'Manila' },
                      { value: 'Asia/Nicosia', text: 'Nicosia' },
                      { value: 'Asia/Novokuznetsk', text: 'Novokuznetsk' },
                      { value: 'Asia/Novosibirsk', text: 'Novosibirsk' },
                      { value: 'Asia/Omsk', text: 'Omsk' },
                      { value: 'Asia/Oral', text: 'Oral' },
                      { value: 'Asia/Pontianak', text: 'Pontianak' },
                      { value: 'Asia/Pyongyang', text: 'Pyongyang' },
                      { value: 'Asia/Qatar', text: 'Qatar' },
                      { value: 'Asia/Qyzylorda', text: 'Qyzylorda' },
                      { value: 'Asia/Riyadh', text: 'Riyadh' },
                      { value: 'Asia/Sakhalin', text: 'Sakhalin' },
                      { value: 'Asia/Samarkand', text: 'Samarkand' },
                      { value: 'Asia/Seoul', text: 'Seoul' },
                      { value: 'Asia/Shanghai', text: 'Shanghai' },
                      { value: 'Asia/Singapore', text: 'Singapore' },
                      { value: 'Asia/Srednekolymsk', text: 'Srednekolymsk' },
                      { value: 'Asia/Taipei', text: 'Taipei' },
                      { value: 'Asia/Tashkent', text: 'Tashkent' },
                      { value: 'Asia/Tbilisi', text: 'Tbilisi' },
                      { value: 'Asia/Tehran', text: 'Tehran' },
                      { value: 'Asia/Thimphu', text: 'Thimphu' },
                      { value: 'Asia/Tokyo', text: 'Tokyo' },
                      { value: 'Asia/Tomsk', text: 'Tomsk' },
                      { value: 'Asia/Ulaanbaatar', text: 'Ulaanbaatar' },
                      { value: 'Asia/Urumqi', text: 'Urumqi' },
                      { value: 'Asia/Ust-Nera', text: 'Ust-Nera' },
                      { value: 'Asia/Vladivostok', text: 'Vladivostok' },
                      { value: 'Asia/Yakutsk', text: 'Yakutsk' },
                      { value: 'Asia/Yangon', text: 'Yangon' },
                      { value: 'Asia/Yekaterinburg', text: 'Yekaterinburg' },
                      { value: 'Asia/Yerevan', text: 'Yerevan' }
                    ]
                  },
                  {
                    group: 'Atlantic',
                    items: [
                      { value: 'Atlantic/Azores', text: 'Azores' },
                      { value: 'Atlantic/Bermuda', text: 'Bermuda' },
                      { value: 'Atlantic/Canary', text: 'Canary' },
                      { value: 'Atlantic/Cape_Verde', text: 'Cape_Verde' },
                      { value: 'Atlantic/Faroe', text: 'Faroe' },
                      { value: 'Atlantic/Madeira', text: 'Madeira' },
                      { value: 'Atlantic/Reykjavik', text: 'Reykjavik' },
                      { value: 'Atlantic/South_Georgia', text: 'South_Georgia' },
                      { value: 'Atlantic/Stanley', text: 'Stanley' }
                    ]
                  },
                  {
                    group: 'Australia',
                    items: [
                      { value: 'Australia/Adelaide', text: 'Adelaide' },
                      { value: 'Australia/Brisbane', text: 'Brisbane' },
                      { value: 'Australia/Broken_Hill', text: 'Broken_Hill' },
                      { value: 'Australia/Currie', text: 'Currie' },
                      { value: 'Australia/Darwin', text: 'Darwin' },
                      { value: 'Australia/Eucla', text: 'Eucla' },
                      { value: 'Australia/Hobart', text: 'Hobart' },
                      { value: 'Australia/Lindeman', text: 'Lindeman' },
                      { value: 'Australia/Lord_Howe', text: 'Lord_Howe' },
                      { value: 'Australia/Melbourne', text: 'Melbourne' },
                      { value: 'Australia/Perth', text: 'Perth' },
                      { value: 'Australia/Sydney', text: 'Sydney' }
                    ]
                  },
                  {
                    group: 'Europe',
                    items: [
                      { value: 'Europe/Amsterdam', text: 'Amsterdam' },
                      { value: 'Europe/Andorra', text: 'Andorra' },
                      { value: 'Europe/Astrakhan', text: 'Astrakhan' },
                      { value: 'Europe/Athens', text: 'Athens' },
                      { value: 'Europe/Belgrade', text: 'Belgrade' },
                      { value: 'Europe/Berlin', text: 'Berlin' },
                      { value: 'Europe/Brussels', text: 'Brussels' },
                      { value: 'Europe/Bucharest', text: 'Bucharest' },
                      { value: 'Europe/Budapest', text: 'Budapest' },
                      { value: 'Europe/Chisinau', text: 'Chisinau' },
                      { value: 'Europe/Copenhagen', text: 'Copenhagen' },
                      { value: 'Europe/Dublin', text: 'Dublin' },
                      { value: 'Europe/Gibraltar', text: 'Gibraltar' },
                      { value: 'Europe/Helsinki', text: 'Helsinki' },
                      { value: 'Europe/Istanbul', text: 'Istanbul' },
                      { value: 'Europe/Kaliningrad', text: 'Kaliningrad' },
                      { value: 'Europe/Kiev', text: 'Kiev' },
                      { value: 'Europe/Kirov', text: 'Kirov' },
                      { value: 'Europe/Lisbon', text: 'Lisbon' },
                      { value: 'Europe/London', text: 'London' },
                      { value: 'Europe/Luxembourg', text: 'Luxembourg' },
                      { value: 'Europe/Madrid', text: 'Madrid' },
                      { value: 'Europe/Malta', text: 'Malta' },
                      { value: 'Europe/Minsk', text: 'Minsk' },
                      { value: 'Europe/Monaco', text: 'Monaco' },
                      { value: 'Europe/Moscow', text: 'Moscow' },
                      { value: 'Europe/Oslo', text: 'Oslo' },
                      { value: 'Europe/Paris', text: 'Paris' },
                      { value: 'Europe/Prague', text: 'Prague' },
                      { value: 'Europe/Riga', text: 'Riga' },
                      { value: 'Europe/Rome', text: 'Rome' },
                      { value: 'Europe/Samara', text: 'Samara' },
                      { value: 'Europe/Saratov', text: 'Saratov' },
                      { value: 'Europe/Simferopol', text: 'Simferopol' },
                      { value: 'Europe/Sofia', text: 'Sofia' },
                      { value: 'Europe/Stockholm', text: 'Stockholm' },
                      { value: 'Europe/Tallinn', text: 'Tallinn' },
                      { value: 'Europe/Tirane', text: 'Tirane' },
                      { value: 'Europe/Ulyanovsk', text: 'Ulyanovsk' },
                      { value: 'Europe/Uzhgorod', text: 'Uzhgorod' },
                      { value: 'Europe/Vienna', text: 'Vienna' },
                      { value: 'Europe/Vilnius', text: 'Vilnius' },
                      { value: 'Europe/Volgograd', text: 'Volgograd' },
                      { value: 'Europe/Warsaw', text: 'Warsaw' },
                      { value: 'Europe/Zaporozhye', text: 'Zaporozhye' },
                      { value: 'Europe/Zurich', text: 'Zurich' }
                    ]
                  },
                  {
                    group: 'Indian',
                    items: [
                      { value: 'Indian/Chagos', text: 'Chagos' },
                      { value: 'Indian/Christmas', text: 'Christmas' },
                      { value: 'Indian/Cocos', text: 'Cocos' },
                      { value: 'Indian/Kerguelen', text: 'Kerguelen' },
                      { value: 'Indian/Mahe', text: 'Mahe' },
                      { value: 'Indian/Maldives', text: 'Maldives' },
                      { value: 'Indian/Mauritius', text: 'Mauritius' },
                      { value: 'Indian/Reunion', text: 'Reunion' }
                    ]
                  },
                  {
                    group: 'Pacific',
                    items: [
                      { value: 'Pacific/Apia', text: 'Apia' },
                      { value: 'Pacific/Auckland', text: 'Auckland' },
                      { value: 'Pacific/Bougainville', text: 'Bougainville' },
                      { value: 'Pacific/Chatham', text: 'Chatham' },
                      { value: 'Pacific/Chuuk', text: 'Chuuk' },
                      { value: 'Pacific/Easter', text: 'Easter' },
                      { value: 'Pacific/Efate', text: 'Efate' },
                      { value: 'Pacific/Enderbury', text: 'Enderbury' },
                      { value: 'Pacific/Fakaofo', text: 'Fakaofo' },
                      { value: 'Pacific/Fiji', text: 'Fiji' },
                      { value: 'Pacific/Funafuti', text: 'Funafuti' },
                      { value: 'Pacific/Galapagos', text: 'Galapagos' },
                      { value: 'Pacific/Gambier', text: 'Gambier' },
                      { value: 'Pacific/Guadalcanal', text: 'Guadalcanal' },
                      { value: 'Pacific/Guam', text: 'Guam' },
                      { value: 'Pacific/Honolulu', text: 'Honolulu' },
                      { value: 'Pacific/Kiritimati', text: 'Kiritimati' },
                      { value: 'Pacific/Kosrae', text: 'Kosrae' },
                      { value: 'Pacific/Kwajalein', text: 'Kwajalein' },
                      { value: 'Pacific/Majuro', text: 'Majuro' },
                      { value: 'Pacific/Marquesas', text: 'Marquesas' },
                      { value: 'Pacific/Nauru', text: 'Nauru' },
                      { value: 'Pacific/Niue', text: 'Niue' },
                      { value: 'Pacific/Norfolk', text: 'Norfolk' },
                      { value: 'Pacific/Noumea', text: 'Noumea' },
                      { value: 'Pacific/Pago_Pago', text: 'Pago_Pago' },
                      { value: 'Pacific/Palau', text: 'Palau' },
                      { value: 'Pacific/Pitcairn', text: 'Pitcairn' },
                      { value: 'Pacific/Pohnpei', text: 'Pohnpei' },
                      { value: 'Pacific/Port_Moresby', text: 'Port_Moresby' },
                      { value: 'Pacific/Rarotonga', text: 'Rarotonga' },
                      { value: 'Pacific/Tahiti', text: 'Tahiti' },
                      { value: 'Pacific/Tarawa', text: 'Tarawa' },
                      { value: 'Pacific/Tongatapu', text: 'Tongatapu' },
                      { value: 'Pacific/Wake', text: 'Wake' },
                      { value: 'Pacific/Wallis', text: 'Wallis' }
                    ]
                  }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Open Monday'),
          cols: [
            {
              namespace: 'Open_Monday',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Open Tuesday'),
          cols: [
            {
              namespace: 'Open_Tuesday',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Open Wednesday'),
          cols: [
            {
              namespace: 'Open_Wednesday',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Open Thursday'),
          cols: [
            {
              namespace: 'Open_Thursday',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Open Friday'),
          cols: [
            {
              namespace: 'Open_Friday',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Open Saturday'),
          cols: [
            {
              namespace: 'Open_Saturday',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Open Sunday'),
          cols: [
            {
              namespace: 'Open_Sunday',
              component: pfFormInput
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Longitude/Latitude'),
      rows: [
        {
          label: i18n.t('Longitude'),
          cols: [
            {
              namespace: 'Longitude',
              component: pfFormInput
            }
          ]
        },
        {
          label: i18n.t('Latitude'),
          cols: [
            {
              namespace: 'Latitude',
              component: pfFormInput
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255),
      [i18n.t('WRIX Location exists.')]: not(and(required, conditional(isNew || isClone), hasWRIXLocations, WRIXLocationExists))
    },
    Provider_Identifier: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Location_Identifier: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Service_Provider_Brand: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Location_Type: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Sub_Location_Type: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    English_Location_Name: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Location_Address1: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Location_Address2: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    English_Location_City: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Location_Zip_Postal_Code: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Location_State_Province_Name: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Location_Country_Name: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Location_Phone_Number: {
      [i18n.t('Value required.')]: required,
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Location_URL: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Coverage_Area: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    SSID_Open_Auth: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    WEP_Key: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    WEP_Key_Entry_Method: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    WEP_Key_Size: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    SSID_1X: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Client_Support: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    MAC_Address: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Open_Monday: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Open_Tuesday: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Open_Wednesday: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Open_Thursday: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Open_Friday: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Open_Saturday: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Open_Sunday: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Longitude: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    },
    Latitude: {
      [i18n.t('Maximum 255 characters.')]: maxLength(255)
    }
  }
}

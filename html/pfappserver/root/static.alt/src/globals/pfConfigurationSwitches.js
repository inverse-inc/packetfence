import i18n from '@/utils/locale'
import pfFieldAction from '@/components/pfFieldAction'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields
} from '@/globals/pfConfiguration'
import { pfFieldType as fieldType } from '@/globals/pfField'
import {
  isPort,
  limitSiblingFields,
  restrictAllSiblingFields
} from '@/globals/pfValidators'

const {
  required,
  ipAddress,
  macAddress,
  integer,
  maxLength
} = require('vuelidate/lib/validators')

export const pfConfigurationSwitchesListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Identifier') }), // re-label
  pfConfigurationListColumns.description,
  pfConfigurationListColumns.group,
  pfConfigurationListColumns.type,
  pfConfigurationListColumns.mode,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationSwitchesListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Identifier') }), // re-text
  pfConfigurationListFields.description,
  pfConfigurationListFields.mode,
  pfConfigurationListFields.type
]

export const pfConfigurationSwitchActions = {
  always: {
    value: 'always',
    text: i18n.t('Always'),
    types: [fieldType.NONE],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate condition.')]: limitSiblingFields('type', 0)
      }
    }
  },
  port: {
    value: 'port',
    text: i18n.t('Port'),
    types: [fieldType.INTEGER],
    validators: {
      type: {
        /* Don't mix with 'always' */
        [i18n.t('Condition conflicts with "Always".')]: restrictAllSiblingFields('type', 'always')
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Invalid Port Number.')]: isPort
      }
    }
  },
  mac: {
    value: 'mac',
    text: i18n.t('MAC Address'),
    types: [fieldType.SUBSTRING],
    validators: {
      type: {
        /* Don't mix with 'always' */
        [i18n.t('Condition conflicts with "Always".')]: restrictAllSiblingFields('type', 'always')
      },
      value: {
        [i18n.t('Value required.')]: required,
        [i18n.t('Invalid MAC Address.')]: macAddress
      }
    }
  },
  ssid: {
    value: 'ssid',
    text: i18n.t('Wi-Fi Network SSID'),
    types: [fieldType.SUBSTRING],
    validators: {
      type: {
        /* Don't mix with 'always' */
        [i18n.t('Condition conflicts with "Always".')]: restrictAllSiblingFields('type', 'always')
      },
      value: {
        [i18n.t('Value required.')]: required
      }
    }
  }
}

export const pfConfigurationSwitchViewFields = (context = {}) => {
  let {
    isNew = false,
    isClone = false,
    placeholders = {}, // form placeholders
    switche = {}, // form
    roles = [], // all roles
    switchGroups = [] // all switchGroups
  } = context

  return [
    {
      tab: i18n.t('Definition'),
      fields: [
        {
          label: i18n.t('IP Address/MAC Address/Range (CIDR)'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Identifier required.')]: required,
                [i18n.t('IP addresses only.')]: ipAddress,
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Description'),
          fields: [
            {
              key: 'notes',
              component: pfFormInput,
              attrs: {
                placeholder: ('notes' in placeholders) ? placeholders.notes : null
              },
              validators: {
                [i18n.t('Description required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Type'),
          fields: [
            {
              key: 'type',
              component: pfFormChosen,
              attrs: {
                placeholder: ('type' in placeholders)
                  ? i18n.t('Choose type (default: "{default}")', { default: placeholders.type })
                  : i18n.t('Choose type'),
                groupLabel: 'group',
                groupValues: 'items',
                label: 'text',
                trackBy: 'value',
                collapseObject: true,
                options: [
                  {
                    group: i18n.t('Accton'),
                    items: [
                      {
                        text: 'Accton ES3526XA',
                        value: 'Accton::ES3526XA'
                      },
                      {
                        text: 'Accton ES3528M',
                        value: 'Accton::ES3528M'
                      }
                    ]
                  },
                  {
                    group: i18n.t('AeroHIVE'),
                    items: [
                      {
                        text: 'AeroHIVE AP',
                        value: 'AeroHIVE::AP'
                      },
                      {
                        text: 'AeroHIVE BR100',
                        value: 'AeroHIVE::BR100'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Alcatel'),
                    items: [
                      {
                        text: 'Alcatel Switch',
                        value: 'Alcatel'
                      }
                    ]
                  },
                  {
                    group: i18n.t('AlliedTelesis'),
                    items: [
                      {
                        text: 'AlliedTelesis AT8000GS',
                        value: 'AlliedTelesis::AT8000GS'
                      },
                      {
                        text: 'AlliedTelesis GS950',
                        value: 'AlliedTelesis::GS950'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Amer'),
                    items: [
                      {
                        text: 'Amer SS2R24i',
                        value: 'Amer::SS2R24i'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Anyfi'),
                    items: [
                      {
                        text: 'Anyfi Gateway',
                        value: 'Anyfi'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Aruba'),
                    items: [
                      {
                        text: 'Aruba Networks',
                        value: 'Aruba'
                      },
                      {
                        text: 'Aruba 2930M Series',
                        value: 'Aruba::2930M'
                      },
                      {
                        text: 'Aruba 5400 Switch',
                        value: 'Aruba::5400'
                      },
                      {
                        text: 'Aruba 200 Controller',
                        value: 'Aruba::Controller_200'
                      }
                    ]
                  },
                  {
                    group: i18n.t('ArubaSwitch'),
                    items: [
                      {
                        text: 'Aruba Switches',
                        value: 'ArubaSwitch'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Avaya'),
                    items: [
                      {
                        text: 'Avaya Switch Module',
                        value: 'Avaya'
                      },
                      {
                        text: 'Avaya ERS 2500 Series',
                        value: 'Avaya::ERS2500'
                      },
                      {
                        text: 'Avaya ERS 3500 Series',
                        value: 'Avaya::ERS3500'
                      },
                      {
                        text: 'Avaya ERS 4000 Series',
                        value: 'Avaya::ERS4000'
                      },
                      {
                        text: 'Avaya ERS 5000 Series',
                        value: 'Avaya::ERS5000'
                      },
                      {
                        text: 'Avaya ERS 5000 Series w/ firmware 6.x',
                        value: 'Avaya::ERS5000_6x'
                      },
                      {
                        text: 'Avaya Wireless Controller',
                        value: 'Avaya::WC'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Belair'),
                    items: [
                      {
                        text: 'Belair Networks AP',
                        value: 'Belair'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Brocade'),
                    items: [
                      {
                        text: 'Brocade Switches',
                        value: 'Brocade'
                      },
                      {
                        text: 'Brocade RF Switches',
                        value: 'Brocade::RFS'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Cambium'),
                    items: [
                      {
                        text: 'Cambium',
                        value: 'Cambium'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Cisco'),
                    items: [
                      {
                        text: 'Cisco Aironet 1130',
                        value: 'Cisco::Aironet_1130'
                      },
                      {
                        text: 'Cisco Aironet 1242',
                        value: 'Cisco::Aironet_1242'
                      },
                      {
                        text: 'Cisco Aironet 1250',
                        value: 'Cisco::Aironet_1250'
                      },
                      {
                        text: 'Cisco Aironet 1600',
                        value: 'Cisco::Aironet_1600'
                      },
                      {
                        text: 'Cisco Aironet (WDS)',
                        value: 'Cisco::Aironet_WDS'
                      },
                      {
                        text: 'Cisco Catalyst 2900XL Series',
                        value: 'Cisco::Catalyst_2900XL'
                      },
                      {
                        text: 'Cisco Catalyst 2950',
                        value: 'Cisco::Catalyst_2950'
                      },
                      {
                        text: 'Cisco Catalyst 2960G',
                        value: 'Cisco::Catalyst_2960G'
                      },
                      {
                        text: 'Cisco Catalyst 2960',
                        value: 'Cisco::Catalyst_2960'
                      },
                      {
                        text: 'Cisco Catalyst 2970',
                        value: 'Cisco::Catalyst_2970'
                      },
                      {
                        text: 'Cisco Catalyst 3500XL Series',
                        value: 'Cisco::Catalyst_3500XL'
                      },
                      {
                        text: 'Cisco Catalyst 3550',
                        value: 'Cisco::Catalyst_3550'
                      },
                      {
                        text: 'Cisco Catalyst 3560G',
                        value: 'Cisco::Catalyst_3560G'
                      },
                      {
                        text: 'Cisco Catalyst 3560',
                        value: 'Cisco::Catalyst_3560'
                      },
                      {
                        text: 'Cisco Catalyst 3750G',
                        value: 'Cisco::Catalyst_3750G'
                      },
                      {
                        text: 'Cisco Catalyst 3750',
                        value: 'Cisco::Catalyst_3750'
                      },
                      {
                        text: 'Cisco Catalyst 4500 Serie',
                        value: 'Cisco::Catalyst_4500'
                      },
                      {
                        text: 'Cisco Catalyst 6500 Series',
                        value: 'Cisco::Catalyst_6500'
                      },
                      {
                        text: 'Cisco ISR 1800 Series',
                        value: 'Cisco::ISR_1800'
                      },
                      {
                        text: 'Cisco SG300',
                        value: 'Cisco::SG300'
                      },
                      {
                        text: 'Cisco WiSM2',
                        value: 'Cisco::WiSM2'
                      },
                      {
                        text: 'Cisco WiSM',
                        value: 'Cisco::WiSM'
                      },
                      {
                        text: 'Cisco Wireless (WLC) 2100 Series',
                        value: 'Cisco::WLC_2100'
                      },
                      {
                        text: 'Cisco Wireless (WLC) 2500 Series',
                        value: 'Cisco::WLC_2500'
                      },
                      {
                        text: 'Cisco Wireless (WLC) 4400 Series',
                        value: 'Cisco::WLC_4400'
                      },
                      {
                        text: 'Cisco Wireless (WLC) 5500 Series',
                        value: 'Cisco::WLC_5500'
                      },
                      {
                        text: 'Cisco Wireless Controller (WLC)',
                        value: 'Cisco::WLC'
                      }
                    ]
                  },
                  {
                    group: i18n.t('CoovaChilli'),
                    items: [
                      {
                        text: 'CoovaChilli',
                        value: 'CoovaChilli'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Dell'),
                    items: [
                      {
                        text: 'Dell Force 10',
                        value: 'Dell::Force10'
                      },
                      {
                        text: 'N1500 Series',
                        value: 'Dell::N1500'
                      },
                      {
                        text: 'Dell PowerConnect 3424',
                        value: 'Dell::PowerConnect3424'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Dlink'),
                    items: [
                      {
                        text: 'D-Link DES 3028',
                        value: 'Dlink::DES_3028'
                      },
                      {
                        text: 'D-Link DES 3526',
                        value: 'Dlink::DES_3526'
                      },
                      {
                        text: 'D-Link DES 3550',
                        value: 'Dlink::DES_3550'
                      },
                      {
                        text: 'D-Link DGS 3100',
                        value: 'Dlink::DGS_3100'
                      },
                      {
                        text: 'D-Link DGS 3200',
                        value: 'Dlink::DGS_3200'
                      },
                      {
                        text: 'D-Link DWL Access-Point',
                        value: 'Dlink::DWL'
                      },
                      {
                        text: 'D-Link DWS 3026',
                        value: 'Dlink::DWS_3026'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Edgecore'),
                    items: [
                      {
                        text: 'Edgecore',
                        value: 'Edgecore'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Enterasys'),
                    items: [
                      {
                        text: 'Enterasys Standalone D2',
                        value: 'Enterasys::D2'
                      },
                      {
                        text: 'Enterasys Matrix N3',
                        value: 'Enterasys::Matrix_N3'
                      },
                      {
                        text: 'Enterasys SecureStack C2',
                        value: 'Enterasys::SecureStack_C2'
                      },
                      {
                        text: 'Enterasys SecureStack C3',
                        value: 'Enterasys::SecureStack_C3'
                      },
                      {
                        text: 'Enterasys V2110',
                        value: 'Enterasys::V2110'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Extreme'),
                    items: [
                      {
                        text: 'ExtremeNet Summit series',
                        value: 'Extreme::Summit'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Extricom'),
                    items: [
                      {
                        text: 'Extricom EXSW Controllers',
                        value: 'Extricom::EXSW'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Fortinet'),
                    items: [
                      {
                        text: 'FortiGate Firewall with web auth + 802.1X',
                        value: 'Fortinet::FortiGate'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Foundry'),
                    items: [
                      {
                        text: 'Foundry FastIron 4802',
                        value: 'Foundry::FastIron_4802'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Generic'),
                    items: [
                      {
                        value: 'Generic',
                        text: 'Generic'
                      }
                    ]
                  },
                  {
                    group: i18n.t('H3C'),
                    items: [
                      {
                        text: 'H3C S5120 (HP/3Com)',
                        value: 'H3C::S5120'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Hostapd'),
                    items: [
                      {
                        value: 'Hostapd',
                        text: 'Hostapd'
                      }
                    ]
                  },
                  {
                    group: i18n.t('HP'),
                    items: [
                      {
                        text: 'HP ProCurve MSM710 Mobility Controller',
                        value: 'HP::Controller_MSM710'
                      },
                      {
                        text: 'HP E4800G (3Com)',
                        value: 'HP::E4800G'
                      },
                      {
                        text: 'HP E5500G (3Com)',
                        value: 'HP::E5500G'
                      },
                      {
                        text: 'HP ProCurve MSM Access Point',
                        value: 'HP::MSM'
                      },
                      {
                        text: 'HP ProCurve 2500 Series',
                        value: 'HP::Procurve_2500'
                      },
                      {
                        text: 'HP ProCurve 2600 Series',
                        value: 'HP::Procurve_2600'
                      },
                      {
                        text: 'HP ProCurve 2920 Series',
                        value: 'HP::Procurve_2920'
                      },
                      {
                        text: 'HP ProCurve 3400cl Series',
                        value: 'HP::Procurve_3400cl'
                      },
                      {
                        text: 'HP ProCurve 4100 Series',
                        value: 'HP::Procurve_4100'
                      },
                      {
                        text: 'HP ProCurve 5300 Series',
                        value: 'HP::Procurve_5300'
                      },
                      {
                        text: 'HP ProCurve 5400 Series',
                        value: 'HP::Procurve_5400'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Huawei'),
                    items: [
                      {
                        text: 'Huawei AC6605',
                        value: 'Huawei'
                      },
                      {
                        text: 'Huawei S5710',
                        value: 'Huawei::S5710'
                      }
                    ]
                  },
                  {
                    group: i18n.t('IBM'),
                    items: [
                      {
                        text: 'IBM RackSwitch G8052',
                        value: 'IBM::IBM_RackSwitch_G8052'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Intel'),
                    items: [
                      {
                        text: 'Intel Express 460',
                        value: 'Intel::Express_460'
                      },
                      {
                        text: 'Intel Express 530',
                        value: 'Intel::Express_530'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Juniper'),
                    items: [
                      {
                        text: 'Juniper EX 2200 Series',
                        value: 'Juniper::EX2200'
                      },
                      {
                        text: 'Juniper EX 2300 Series',
                        value: 'Juniper::EX2300'
                      },
                      {
                        text: 'Juniper EX Series',
                        value: 'Juniper::EX'
                      }
                    ]
                  },
                  {
                    group: i18n.t('LG'),
                    items: [
                      {
                        text: 'LG-Ericsson iPECS ES-4500G',
                        value: 'LG::ES4500G'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Linksys'),
                    items: [
                      {
                        text: 'Linksys SRW224G4',
                        value: 'Linksys::SRW224G4'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Meraki'),
                    items: [
                      {
                        text: 'Meraki cloud controller',
                        value: 'Meraki::MR'
                      },
                      {
                        text: 'Meraki cloud controller V2',
                        value: 'Meraki::MR_v2'
                      },
                      {
                        text: 'Meraki switch MS220_8',
                        value: 'Meraki::MS220_8'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Meru'),
                    items: [
                      {
                        text: 'Meru MC',
                        value: 'Meru::MC'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Mikrotik'),
                    items: [
                      {
                        value: 'Mikrotik',
                        text: 'Mikrotik'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Mojo'),
                    items: [
                      {
                        text: 'Mojo Networks AP',
                        value: 'Mojo'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Motorola'),
                    items: [
                      {
                        text: 'Motorola RF Switches',
                        value: 'Motorola::RFS'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Netgear'),
                    items: [
                      {
                        text: 'Netgear FSM726v1',
                        value: 'Netgear::FSM726v1'
                      },
                      {
                        text: 'Netgear FSM7328S',
                        value: 'Netgear::FSM7328S'
                      },
                      {
                        text: 'Netgear GS110',
                        value: 'Netgear::GS110'
                      },
                      {
                        text: 'Netgear M series',
                        value: 'Netgear::MSeries'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Nortel'),
                    items: [
                      {
                        text: 'Nortel BayStack 4550',
                        value: 'Nortel::BayStack4550'
                      },
                      {
                        text: 'Nortel BayStack 470',
                        value: 'Nortel::BayStack470'
                      },
                      {
                        text: 'Nortel BayStack 5500 w/ firmware 6.x',
                        value: 'Nortel::BayStack5500_6x'
                      },
                      {
                        text: 'Nortel BayStack 5500 Series',
                        value: 'Nortel::BayStack5500'
                      },
                      {
                        text: 'Nortel BPS 2000',
                        value: 'Nortel::BPS2000'
                      },
                      {
                        text: 'Nortel ERS 2500 Series',
                        value: 'Nortel::ERS2500'
                      },
                      {
                        text: 'Nortel ERS 4000 Series',
                        value: 'Nortel::ERS4000'
                      },
                      {
                        text: 'Nortel ERS 5000 Series w/ firmware 6.x',
                        value: 'Nortel::ERS5000_6x'
                      },
                      {
                        text: 'Nortel ERS 5000 Series',
                        value: 'Nortel::ERS5000'
                      },
                      {
                        text: 'Nortel ES325',
                        value: 'Nortel::ES325'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Packetfence'),
                    items: [
                      {
                        text: 'Packetfence',
                        value: 'Packetfence'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Ruckus'),
                    items: [
                      {
                        text: 'Legacy',
                        value: 'Ruckus::Legacy - Ruckus Wireless Controllers'
                      },
                      {
                        text: 'Ruckus Wireless Controllers',
                        value: 'Ruckus'
                      },
                      {
                        text: 'Ruckus SmartZone Wireless Controllers',
                        value: 'Ruckus::SmartZone'
                      }
                    ]
                  },
                  {
                    group: i18n.t('SMC'),
                    items: [
                      {
                        text: 'SMC TigerStack 6128L2',
                        value: 'SMC::TS6128L2'
                      },
                      {
                        text: 'SMC TigerStack 6224M',
                        value: 'SMC::TS6224M'
                      },
                      {
                        text: 'SMC TigerStack 8800 Series',
                        value: 'SMC::TS8800M'
                      }
                    ]
                  },
                  {
                    group: i18n.t('ThreeCom'),
                    items: [
                      {
                        text: '3COM E4800G',
                        value: 'ThreeCom::E4800G'
                      },
                      {
                        text: '3COM E5500G',
                        value: 'ThreeCom::E5500G'
                      },
                      {
                        text: '3COM NJ220',
                        value: 'ThreeCom::NJ220'
                      },
                      {
                        text: '3COM SS4200',
                        value: 'ThreeCom::SS4200'
                      },
                      {
                        text: '3COM SS4500',
                        value: 'ThreeCom::SS4500'
                      },
                      {
                        text: '3COM 4200G',
                        value: 'ThreeCom::Switch_4200G'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Trapeze'),
                    items: [
                      {
                        text: 'Trapeze Wireless Controller',
                        value: 'Trapeze'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Ubiquiti'),
                    items: [
                      {
                        text: 'EdgeSwitch',
                        value: 'Ubiquiti::EdgeSwitch'
                      },
                      {
                        text: 'Unifi Controller',
                        value: 'Ubiquiti::Unifi'
                      }
                    ]
                  },
                  {
                    group: i18n.t('Xirrus'),
                    items: [
                      {
                        text: 'Xirrus WiFi Arrays',
                        value: 'Xirrus'
                      }
                    ]
                  }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Mode'),
          fields: [
            {
              key: 'mode',
              component: pfFormChosen,
              attrs: {
                placeholder: ('mode' in placeholders)
                  ? i18n.t('Choose mode (default: "{default}")', { default: placeholders.mode })
                  : i18n.t('Choose mode'),
                label: 'text',
                trackBy: 'value',
                collapseObject: true,
                allowEmpty: false,
                options: [
                  {
                    text: i18n.t('Testing'),
                    value: 'testing'
                  },
                  {
                    text: i18n.t('Registration'),
                    value: 'registration'
                  },
                  {
                    text: i18n.t('Production'),
                    value: 'production'
                  }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Switch Group'),
          fields: [
            {
              key: 'group',
              component: pfFormChosen,
              attrs: {
                placeholder: ('group' in placeholders)
                  ? i18n.t('Choose group (default: "{default}")', { default: placeholders.group })
                  : i18n.t('Choose group'),
                label: 'text',
                trackBy: 'value',
                collapseObject: true,
                allowEmpty: false,
                options: [
                  { value: null, text: i18n.t('None') }, // prepend null option
                  ...switchGroups.map(group => { return { value: group.id, text: `${group.id} - ${group.description}` } })
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Deauthentication Method'),
          fields: [
            {
              key: 'deauthMethod',
              component: pfFormChosen,
              attrs: {
                placeholder: ('deauthMethod' in placeholders)
                  ? i18n.t('Choose method (default: "{default}")', { default: placeholders.deauthMethod })
                  : i18n.t('Choose method'),
                label: 'text',
                trackBy: 'value',
                collapseObject: true,
                options: [
                  {
                    text: i18n.t('Telnet'),
                    value: 'Telnet'
                  },
                  {
                    text: i18n.t('SSH'),
                    value: 'SSH'
                  },
                  {
                    text: i18n.t('SNMP'),
                    value: 'SNMP'
                  },
                  {
                    text: i18n.t('RADIUS'),
                    value: 'RADIUS'
                  },
                  {
                    text: i18n.t('HTTP'),
                    value: 'HTTP'
                  },
                  {
                    text: i18n.t('HTTPS'),
                    value: 'HTTPS'
                  }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Use CoA'),
          text: i18n.t('Use CoA when available to deauthenticate the user. When disabled, RADIUS Disconnect will be used instead if it is available.'),
          fields: [
            {
              key: 'useCoA',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          label: i18n.t('CLI Access Enabled'),
          text: i18n.t('Allow this switch to use PacketFence as a radius server for CLI access.'),
          fields: [
            {
              key: 'cliAccess',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          label: i18n.t('External Portal Enforcement'),
          text: i18n.t('Enable external portal enforcement when supported by network equipment.'),
          fields: [
            {
              key: 'ExternalPortalEnforcement',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          label: i18n.t('VOIP'),
          fields: [
            {
              key: 'VoIPEnabled',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          label: i18n.t('VoIPLLDPDetect'),
          text: i18n.t('Detect VoIP with a SNMP request in the LLDP MIB.'),
          fields: [
            {
              key: 'VoIPLLDPDetect',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          label: i18n.t('VoIPCDPDetect'),
          text: i18n.t('Detect VoIP with a SNMP request in the CDP MIB.'),
          fields: [
            {
              key: 'VoIPCDPDetect',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          label: i18n.t('VoIPDHCPDetect'),
          text: i18n.t('Detect VoIP with the DHCP Fingerprint.'),
          fields: [
            {
              key: 'VoIPDHCPDetect',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          label: i18n.t('Dynamic Uplinks'),
          text: i18n.t('Dynamically lookup uplinks.'),
          fields: [
            {
              key: 'uplink_dynamic',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'dynamic', unchecked: null }
              },
              listeners: {
                checked: (value) => {
                  switche.uplink = null // clear uplink
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Static Uplinks'),
          text: i18n.t('Comma-separated list of the switch uplinks.'),
          if: (switche.uplink_dynamic !== 'dynamic'),
          fields: [
            {
              key: 'uplink',
              component: pfFormInput,
              attrs: {
                placeholder: ('uplink' in placeholders) ? placeholders.uplink : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Controller IP Address'),
          text: i18n.t('Use instead this IP address for de-authentication requests. Normally used for Wi-Fi only.'),
          fields: [
            {
              key: 'controllerIp',
              component: pfFormInput,
              attrs: {
                placeholder: ('controllerIp' in placeholders) ? placeholders.controllerIp : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('IP addresses only.')]: ipAddress
              }
            }
          ]
        },
        {
          label: i18n.t('Disconnect Port'),
          text: i18n.t('For Disconnect request, if we have to send to another port.'),
          fields: [
            {
              key: 'disconnectPort',
              component: pfFormInput,
              attrs: {
                placeholder: ('disconnectPort' in placeholders) ? placeholders.disconnectPort : null,
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Invalid Port Number.')]: isPort
              }
            }
          ]
        },
        {
          label: i18n.t('CoA Port'),
          text: i18n.t('For CoA request, if we have to send to another port.'),
          fields: [
            {
              key: 'coaPort',
              component: pfFormInput,
              attrs: {
                placeholder: ('coaPort' in placeholders) ? placeholders.coaPort : null,
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Invalid Port Number.')]: isPort
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Roles'),
      fields: [
        { label: i18n.t('Role mapping by VLAN ID'), labelSize: 'lg' },
        {
          label: i18n.t('Role by VLAN ID'),
          fields: [
            {
              key: 'VlanMap',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        ...[
          'registration',
          'isolation',
          'macDetection',
          'inline',
          ...roles.map(role => role.id)
        ].map(role => {
          return {
            label: i18n.t(role),
            if: (switche.VlanMap === 'Y'),
            fields: [
              {
                key: `${role}Vlan`,
                component: pfFormInput,
                attrs: {
                  placeholder: (`${role}Vlan` in placeholders) ? placeholders[`${role}Vlan`] : null
                },
                validators: {
                  [i18n.t('Maximum 255 characters.')]: maxLength(255)
                }
              }
            ]
          }
        }),
        { label: i18n.t('Role mapping by Switch Role'), labelSize: 'lg' },
        {
          label: i18n.t('Role by Switch Role'),
          fields: [
            {
              key: 'RoleMap',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        ...[
          'registration',
          'isolation',
          'macDetection',
          'inline',
          ...roles.map(role => role.id)
        ].map(role => {
          return {
            label: i18n.t(role),
            if: (switche.RoleMap === 'Y'),
            fields: [
              {
                key: `${role}Role`,
                component: pfFormInput,
                attrs: {
                  placeholder: (`${role}Role` in placeholders) ? placeholders[`${role}Role`] : null
                },
                validators: {
                  [i18n.t('Maximum 255 characters.')]: maxLength(255)
                }
              }
            ]
          }
        }),
        { label: i18n.t('Role mapping by Access List'), labelSize: 'lg' },
        {
          label: i18n.t('Role by Access List'),
          fields: [
            {
              key: 'AccessListMap',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        ...[
          'registration',
          'isolation',
          'macDetection',
          'inline',
          ...roles.map(role => role.id)
        ].map(role => {
          return {
            label: i18n.t(role),
            if: (switche.AccessListMap === 'Y'),
            fields: [
              {
                key: `${role}AccessList`,
                component: pfFormTextarea,
                attrs: {
                  rows: 3,
                  placeholder: (`${role}AccessList` in placeholders) ? placeholders[`${role}AccessList`] : null
                },
                validators: {
                  [i18n.t('Maximum 255 characters.')]: maxLength(255)
                }
              }
            ]
          }
        }),
        { label: i18n.t('Role mapping by Web Auth URL'), labelSize: 'lg' },
        {
          label: i18n.t('Role by Web Auth URL'),
          fields: [
            {
              key: 'UrlMap',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        ...[
          'registration',
          'isolation',
          'macDetection',
          'inline',
          ...roles.map(role => role.id)
        ].map(role => {
          return {
            label: i18n.t(role),
            if: (switche.UrlMap === 'Y'),
            fields: [
              {
                key: `${role}Url`,
                component: pfFormInput,
                attrs: {
                  placeholder: (`${role}Url` in placeholders) ? placeholders[`${role}Url`] : null
                },
                validators: {
                  [i18n.t('Maximum 255 characters.')]: maxLength(255)
                }
              }
            ]
          }
        })
      ]
    },
    {
      tab: i18n.t('Inline'),
      fields: [
        {
          label: i18n.t('Inline Conditions'),
          text: i18n.t('Set inline mode if any of the conditions are met.'),
          fields: [
            {
              key: 'inlineTrigger',
              component: pfFormFields,
              attrs: {
                buttonLabel: 'Add Condition',
                sortable: false,
                field: {
                  component: pfFieldAction,
                  attrs: {
                    typeLabel: i18n.t('Select condition type'),
                    valueLabel: i18n.t('Select condition value'),
                    fields: [
                      pfConfigurationSwitchActions.always,
                      pfConfigurationSwitchActions.port,
                      pfConfigurationSwitchActions.mac,
                      pfConfigurationSwitchActions.ssid
                    ]
                  }
                },
                invalidFeedback: [
                  { [i18n.t('Condition(s) contain one or more errors.')]: true }
                ]
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('RADIUS'),
      fields: [
        {
          label: i18n.t('Secret Passphrase'),
          fields: [
            {
              key: 'radiusSecret',
              component: pfFormPassword,
              attrs: {
                placeholder: ('radiusSecret' in placeholders) ? placeholders.radiusSecret : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('SNMP'),
      fields: [
        {
          label: i18n.t('Version'),
          fields: [
            {
              key: 'SNMPVersion',
              component: pfFormChosen,
              attrs: {
                placeholder: ('SNMPVersion' in placeholders)
                  ? i18n.t('Choose version (default: "v{default}")', { default: placeholders.SNMPVersion })
                  : i18n.t('Choose version'),
                label: 'text',
                trackBy: 'value',
                collapseObject: true,
                options: [
                  {
                    text: i18n.t('v1'),
                    value: '1'
                  },
                  {
                    text: i18n.t('v2c'),
                    value: '2c'
                  },
                  {
                    text: i18n.t('v3'),
                    value: '3'
                  }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Community Read'),
          fields: [
            {
              key: 'SNMPCommunityRead',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPCommunityRead' in placeholders) ? placeholders.SNMPCommunityRead : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Community Write'),
          fields: [
            {
              key: 'SNMPCommunityWrite',
              component: pfFormInput,
              attrs: {
                placeholder: ('private' in placeholders) ? placeholders.private : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Engine ID'),
          fields: [
            {
              key: 'SNMPEngineID',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPEngineID' in placeholders) ? placeholders.SNMPEngineID : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('User Name Read'),
          fields: [
            {
              key: 'SNMPUserNameRead',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPUserNameRead' in placeholders) ? placeholders.SNMPUserNameRead : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Auth Protocol Read'),
          fields: [
            {
              key: 'SNMPAuthProtocolRead',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPAuthProtocolRead' in placeholders) ? placeholders.SNMPAuthProtocolRead : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Auth Password Read'),
          fields: [
            {
              key: 'SNMPAuthPasswordRead',
              component: pfFormPassword,
              attrs: {
                placeholder: ('SNMPAuthPasswordRead' in placeholders) ? placeholders.SNMPAuthPasswordRead : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Priv Protocol Read'),
          fields: [
            {
              key: 'SNMPPrivProtocolRead',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPPrivProtocolRead' in placeholders) ? placeholders.SNMPPrivProtocolRead : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Priv Password Read'),
          fields: [
            {
              key: 'SNMPPrivPasswordRead',
              component: pfFormPassword,
              attrs: {
                placeholder: ('SNMPPrivPasswordRead' in placeholders) ? placeholders.SNMPPrivPasswordRead : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('User Name Write'),
          fields: [
            {
              key: 'SNMPUserNameWrite',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPUserNameWrite' in placeholders) ? placeholders.SNMPUserNameWrite : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Auth Protocol Write'),
          fields: [
            {
              key: 'SNMPAuthProtocolWrite',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPAuthProtocolWrite' in placeholders) ? placeholders.SNMPAuthProtocolWrite : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Auth Password Write'),
          fields: [
            {
              key: 'SNMPAuthPasswordWrite',
              component: pfFormPassword,
              attrs: {
                placeholder: ('SNMPAuthPasswordWrite' in placeholders) ? placeholders.SNMPAuthPasswordWrite : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Priv Protocol Write'),
          fields: [
            {
              key: 'SNMPPrivProtocolWrite',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPPrivProtocolWrite' in placeholders) ? placeholders.SNMPPrivProtocolWrite : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Priv Password Write'),
          fields: [
            {
              key: 'SNMPPrivPasswordWrite',
              component: pfFormPassword,
              attrs: {
                placeholder: ('SNMPPrivPasswordWrite' in placeholders) ? placeholders.SNMPPrivPasswordWrite : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Version Trap'),
          fields: [
            {
              key: 'SNMPVersionTrap',
              component: pfFormChosen,
              attrs: {
                placeholder: ('SNMPVersionTrap' in placeholders)
                  ? i18n.t('Choose version (default: "v{default}")', { default: placeholders.SNMPVersionTrap })
                  : i18n.t('Choose version'),
                label: 'text',
                trackBy: 'value',
                collapseObject: true,
                options: [
                  {
                    text: i18n.t('v1'),
                    value: '1'
                  },
                  {
                    text: i18n.t('v2c'),
                    value: '2c'
                  },
                  {
                    text: i18n.t('v3'),
                    value: '3'
                  }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Community Trap'),
          fields: [
            {
              key: 'SNMPCommunityTrap',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPCommunityTrap' in placeholders) ? placeholders.SNMPCommunityTrap : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('User Name Trap'),
          fields: [
            {
              key: 'SNMPUserNameTrap',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPUserNameTrap' in placeholders) ? placeholders.SNMPUserNameTrap : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Auth Protocol Trap'),
          fields: [
            {
              key: 'SNMPAuthProtocolTrap',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPAuthProtocolTrap' in placeholders) ? placeholders.SNMPAuthProtocolTrap : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Auth Password Trap'),
          fields: [
            {
              key: 'SNMPAuthPasswordTrap',
              component: pfFormPassword,
              attrs: {
                placeholder: ('SNMPAuthPasswordTrap' in placeholders) ? placeholders.SNMPAuthPasswordTrap : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Priv Protocol Trap'),
          fields: [
            {
              key: 'SNMPPrivProtocolTrap',
              component: pfFormInput,
              attrs: {
                placeholder: ('SNMPPrivProtocolTrap' in placeholders) ? placeholders.SNMPPrivProtocolTrap : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Priv Password Trap'),
          fields: [
            {
              key: 'SNMPPrivPasswordTrap',
              component: pfFormPassword,
              attrs: {
                placeholder: ('SNMPPrivPasswordTrap' in placeholders) ? placeholders.SNMPPrivPasswordTrap : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Maximum MAC addresses'),
          text: i18n.t('Maximum number of MAC addresses retrived from a port.'),
          fields: [
            {
              key: 'macSearchesMaxNb',
              component: pfFormInput,
              attrs: {
                placeholder: ('macSearchesMaxNb' in placeholders) ? placeholders.macSearchesMaxNb : null,
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Integer values required.')]: integer
              }
            }
          ]
        },
        {
          label: i18n.t('Sleep interval'),
          text: i18n.t('Sleep interval between queries of MAC addresses.'),
          fields: [
            {
              key: 'macSearchesSleepInterval',
              component: pfFormInput,
              attrs: {
                placeholder: ('macSearchesSleepInterval' in placeholders) ? placeholders.macSearchesSleepInterval : null,
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Integer values required.')]: integer
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('CLI'),
      fields: [
        {
          label: i18n.t('Transport'),
          fields: [
            {
              key: 'cliTransport',
              component: pfFormChosen,
              attrs: {
                placeholder: ('cliTransport' in placeholders)
                  ? i18n.t('Choose transport (default: "{default}")', { default: placeholders.cliTransport })
                  : i18n.t('Choose transport'),
                label: 'text',
                trackBy: 'value',
                collapseObject: true,
                options: [
                  {
                    text: i18n.t('Telnet'),
                    value: 'Telnet'
                  },
                  {
                    text: i18n.t('SSH'),
                    value: 'SSH'
                  }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Username'),
          fields: [
            {
              key: 'cliUser',
              component: pfFormInput,
              attrs: {
                placeholder: ('cliUser' in placeholders) ? placeholders.cliUser : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Password'),
          fields: [
            {
              key: 'cliPwd',
              component: pfFormPassword,
              attrs: {
                placeholder: ('cliPwd' in placeholders) ? placeholders.cliPwd : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Enable Password'),
          fields: [
            {
              key: 'cliEnablePwd',
              component: pfFormPassword,
              attrs: {
                placeholder: ('cliEnablePwd' in placeholders) ? placeholders.cliEnablePwd : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Web Services'),
      fields: [
        {
          label: i18n.t('Transport'),
          fields: [
            {
              key: 'wsTransport',
              component: pfFormChosen,
              attrs: {
                placeholder: ('wsTransport' in placeholders)
                  ? i18n.t('Choose transport (default: "{default}")', { default: placeholders.wsTransport })
                  : i18n.t('Choose transport'),
                label: 'text',
                trackBy: 'value',
                collapseObject: true,
                options: [
                  {
                    text: i18n.t('HTTP'),
                    value: 'HTTP'
                  },
                  {
                    text: i18n.t('HTTPS'),
                    value: 'HTTPS'
                  }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Username'),
          fields: [
            {
              key: 'wsUser',
              component: pfFormInput,
              attrs: {
                placeholder: ('wsUser' in placeholders) ? placeholders.wsUser : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Password'),
          fields: [
            {
              key: 'wsPwd',
              component: pfFormPassword,
              attrs: {
                placeholder: ('wsPwd' in placeholders) ? placeholders.wsPwd : null
              },
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        }
      ]
    }
  ]
}

export const pfConfigurationSwitchViewPlaceholders = (context = {}) => {
  // TODO: replace with inherited defaults from conf/switches.conf.defaults
  return {
    vlans: '1,2,3,4,5',
    normalVlan: '1',
    registrationVlan: '2',
    isolationVlan: '3',
    macDetectionVlan: '4',
    voiceVlan: '5',
    inlineVlan: '6',
    REJECTVlan: '-1',
    voiceRole: 'voice',
    inlineRole: 'inline',
    TenantId: '1',
    mode: 'production',
    macSearchesMaxNb: '30',
    macSearchesSleepInterval: '2',
    uplink: 'dynamic',
    cliTransport: 'Telnet',
    SNMPVersion: '1',
    SNMPCommunityRead: 'public',
    SNMPCommunityWrite: 'private',
    SNMPVersionTrap: '1',
    SNMPCommunityTrap: 'public',
    wsTransport: 'http'
  }
}

export const pfConfigurationSwitchViewDefaults = (context = {}) => {
  // TODO: replace with inherited defaults from conf/switches.conf.defaults
  return {
    id: null,
    AccessListMap: 'N',
    cliAccess: 'N',
    ExternalPortalEnforcement: 'N',
    RoleMap: 'N',
    UrlMap: 'N',
    useCoA: 'Y',
    VlanMap: 'Y',
    VoIPEnabled: 'N',
    VoIPCDPDetect: 'Y',
    VoIPDHCPDetect: 'Y',
    VoIPLLDPDetect: 'Y'
  }
}

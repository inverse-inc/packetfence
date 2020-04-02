import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasFirewalls,
  firewallExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: 'Hostname or IP', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'type',
    label: 'Firewall Type', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'port',
    label: 'Port', // i18n defer
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
    text: i18n.t('Name'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'type',
    text: i18n.t('Type'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'port',
    text: i18n.t('Port'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'firewall', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by hostname, ip, port or firewall type'),
    searchableOptions: {
      searchApiEndpoint: 'config/firewalls',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'port', op: 'contains', value: null },
            { field: 'type', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'firewalls' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: quickCondition },
            { field: 'port', op: 'contains', value: quickCondition },
            { field: 'type', op: 'contains', value: quickCondition }
          ]
        }]
      }
    }
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false,
    firewallType = null
  } = meta
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: 'Hostname or IP Address', // i18n defer
          text: ['FamilyZone'].includes(firewallType) ? i18n.t('Include the region in the FQDN when using the cloud version (ex: login.myregion.linewize.net).') : null,
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              }
            }
          ]
        },
        {
          if: ['BarracudaNG', 'JSONRPC', 'JuniperSRX', 'FamilyZone'].includes(firewallType),
          label: 'Username', // i18n defer
          cols: [
            {
              namespace: 'username',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'username')
            }
          ]
        },
        {
          if: ['BarracudaNG', 'Checkpoint', 'FortiGate', 'Iboss', 'JuniperSRX', 'WatchGuard', 'LightSpeedRocket', 'SmoothWall', 'FamilyZone'].includes(firewallType),
          label: 'Secret or Key', // i18n defer
          cols: [
            {
              namespace: 'password',
              component: pfFormPassword,
              attrs: attributesFromMeta(meta, 'password')
            }
          ]
        },
        {
          if: ['JSONRPC'].includes(firewallType),
          label: 'Password', // i18n defer
          cols: [
            {
              namespace: 'password',
              component: pfFormPassword,
              attrs: attributesFromMeta(meta, 'password')
            }
          ]
        },
        {
          if: ['BarracudaNG', 'Checkpoint', 'FortiGate', 'Iboss', 'JuniperSRX', 'WatchGuard', 'JSONRPC', 'LightSpeedRocket', 'SmoothWall', 'CiscoIsePic'].includes(firewallType),
          label: 'Port of the service', // i18n defer
          text: i18n.t('If you use an alternative port, please specify.'),
          cols: [
            {
              namespace: 'port',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'port')
            }
          ]
        },
        {
          if: ['PaloAlto'].includes(firewallType),
          label: 'Vsys', // i18n defer
          text: i18n.t('Please define the Virtual System number. This only has an effect when used with the HTTP transport.'),
          cols: [
            {
              namespace: 'vsys',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'vsys')
            }
          ]
        },
        {
          if: ['FamilyZone'].includes(firewallType),
          label: 'DeviceID', // i18n defer
          text: i18n.t('Please define the DeviceID.'),
          cols: [
            {
              namespace: 'deviceid',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'deviceid')
            }
          ]
        },
        {
          if: ['PaloAlto'].includes(firewallType),
          label: 'Transport', // i18n defer
          cols: [
            {
              namespace: 'transport',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'transport')
            }
          ]
        },
        {
          if: ['PaloAlto'].includes(firewallType),
          label: 'Port of the service', // i18n defer
          text: i18n.t('If you use an alternative port, please specify. This parameter is ignored when the Syslog transport is selected.'),
          cols: [
            {
              namespace: 'port',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'port')
            }
          ]
        },
        {
          if: ['PaloAlto'].includes(firewallType),
          label: 'Secret or Key', // i18n defer
          text: i18n.t('If using the HTTP transport, specify the password for the Palo Alto API.'),
          cols: [
            {
              namespace: 'password',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'password')
            }
          ]
        },
        {
          if: ['Iboss'].includes(firewallType),
          label: 'NAC name', // i18n defer
          text: i18n.t('Should match the NAC name from the Iboss configuration.'),
          cols: [
            {
              namespace: 'nac_name',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'nac_name')
            }
          ]
        },
        {
          label: 'Roles', // i18n defer
          text: i18n.t('Nodes with the selected roles will be affected.'),
          cols: [
            {
              namespace: 'categories',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'categories')
            }
          ]
        },
        {
          label: 'Networks on which to do SSO', // i18n defer
          text: i18n.t('Comma delimited list of networks on which the SSO applies.\nFormat : 192.168.0.0/24'),
          cols: [
            {
              namespace: 'networks',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'networks')
            }
          ]
        },
        {
          label: 'Cache updates', // i18n defer
          text: i18n.t('Enable this to debounce updates to the Firewall.\nBy default, PacketFence will send a SSO on every DHCP request for every device. Enabling this enables "sleep" periods during which the update is not sent if the informations stay the same.'),
          cols: [
            {
              namespace: 'cache_updates',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Cache timeout', // i18n defer
          text: i18n.t('Adjust the "Cache timeout" to half the expiration delay in your firewall.\nYour DHCP renewal interval should match this value.'),
          cols: [
            {
              namespace: 'cache_timeout',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'cache_timeout')
            }
          ]
        },
        {
          label: 'Username format', // i18n defer
          text: i18n.t('Defines how to format the username that is sent to your firewall. $username represents the username and $realm represents the realm of your user if applicable. $pf_username represents the unstripped username as it is stored in the PacketFence database. If left empty, it will use the username as stored in PacketFence (value of $pf_username).'),
          cols: [
            {
              namespace: 'username_format',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'username_format')
            }
          ]
        },
        {
          label: 'Default realm', // i18n defer
          text: i18n.t('The default realm to be used while formatting the username when no realm can be extracted from the username.'),
          cols: [
            {
              namespace: 'default_realm',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'default_realm')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', 'ID'),
      ...{
        [i18n.t('Firewall exists.')]: not(and(required, conditional(isNew || isClone), hasFirewalls, firewallExists))
      }
    },
    username: validatorsFromMeta(meta, 'username', i18n.t('Username')),
    password: validatorsFromMeta(meta, 'password', i18n.t('Password')),
    port: validatorsFromMeta(meta, 'port', i18n.t('Port')),
    vsys: validatorsFromMeta(meta, 'vsys', i18n.t('Number')),
    deviceid: validatorsFromMeta(meta, 'deviceid', i18n.t('DeviceID')),
    transport: validatorsFromMeta(meta, 'transport', i18n.t('Transport')),
    nac_name: validatorsFromMeta(meta, 'nac_name', i18n.t('Name')),
    categories: validatorsFromMeta(meta, 'categories', i18n.t('Roles')),
    networks: validatorsFromMeta(meta, 'networks', i18n.t('Networks')),
    cache_timeout: validatorsFromMeta(meta, 'cache_timeout', i18n.t('Timeout')),
    username_format: validatorsFromMeta(meta, 'username_format', i18n.t('Format')),
    default_realm: validatorsFromMeta(meta, 'default_realm', i18n.t('Realm'))
  }
}

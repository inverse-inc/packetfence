import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields
} from '@/globals/configuration/pfConfiguration'
import {
  and,
  or,
  not,
  conditional,
  isFQDN,
  isPort,
  hasFirewalls,
  firewallExists
} from '@/globals/pfValidators'

const {
  ipAddress,
  maxLength,
  numeric,
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationFirewallsListColumns = [
  { ...pfConfigurationListColumns.id, ...{ label: i18n.t('Hostname or IP') } }, // re-label
  { ...pfConfigurationListColumns.type, ...{ label: i18n.t('Firewall Type') } }, // re-label
  pfConfigurationListColumns.port,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationFirewallsListFields = [
  { ...pfConfigurationListFields.id, ...{ text: i18n.t('Name') } }, // re-text
  pfConfigurationListFields.type,
  pfConfigurationListFields.port
]

export const pfConfigurationFirewallsListConfig = (context = {}) => {
  return {
    columns: pfConfigurationFirewallsListColumns,
    fields: pfConfigurationFirewallsListFields,
    rowClickRoute (item, index) {
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

export const pfConfigurationFirewallViewFields = (context) => {
  const {
    isNew = false,
    isClone = false,
    firewallType = null,
    roles = []
  } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          label: i18n.t('Hostname or IP Address'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Value required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255),
                [i18n.t('Invalid Hostname or IP Address.')]: or(isFQDN, ipAddress),
                [i18n.t('Firewall exists.')]: not(and(required, conditional(isNew || isClone), hasFirewalls, firewallExists))
              }
            }
          ]
        },
        {
          if: ['BarracudaNG', 'JSONRPC'].includes(firewallType),
          label: i18n.t('Username'),
          fields: [
            {
              key: 'username',
              component: pfFormInput,
              validators: {
                [i18n.t('Value required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          if: ['BarracudaNG', 'Checkpoint', 'FortiGate', 'Iboss', 'JuniperSRX', 'WatchGuard'].includes(firewallType),
          label: i18n.t('Secret or Key'),
          fields: [
            {
              key: 'password',
              component: pfFormPassword,
              validators: {
                [i18n.t('Value required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          if: ['JSONRPC'].includes(firewallType),
          label: i18n.t('Password'),
          fields: [
            {
              key: 'password',
              component: pfFormPassword,
              validators: {
                [i18n.t('Value required.')]: required,
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          if: ['BarracudaNG', 'Checkpoint', 'FortiGate', 'Iboss', 'JuniperSRX', 'WatchGuard', 'JSONRPC'].includes(firewallType),
          label: i18n.t('Port of the service'),
          text: i18n.t('If you use an alternative port, please specify.'),
          fields: [
            {
              key: 'port',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Invalid Port Number.')]: isPort
              }
            }
          ]
        },
        {
          if: ['PaloAlto'].includes(firewallType),
          label: i18n.t('Vsys'),
          text: i18n.t('Please define the Virtual System number. This only has an effect when used with the HTTP transport.'),
          fields: [
            {
              key: 'vsys',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Positive numbers only.')]: numeric,
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          if: ['PaloAlto'].includes(firewallType),
          label: i18n.t('Transport'),
          fields: [
            {
              key: 'transport',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to add a transport'),
                trackBy: 'value',
                label: 'text',
                options: [
                  { value: 'syslog', text: 'Syslog' },
                  { value: 'http', text: 'HTTP' }
                ]
              }
            }
          ]
        },
        {
          if: ['PaloAlto'].includes(firewallType),
          label: i18n.t('Port of the service'),
          text: i18n.t('If you use an alternative port, please specify. This parameter is ignored when the Syslog transport is selected.'),
          fields: [
            {
              key: 'port',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Invalid Port Number.')]: isPort
              }
            }
          ]
        },
        {
          if: ['PaloAlto'].includes(firewallType),
          label: i18n.t('Secret or Key'),
          text: i18n.t('If using the HTTP transport, specify the password for the Palo Alto API.'),
          fields: [
            {
              key: 'password',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          if: ['Iboss'].includes(firewallType),
          label: i18n.t('NAC name'),
          text: i18n.t('Should match the NAC name from the Iboss configuration.'),
          fields: [
            {
              key: 'nac_name',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Roles'),
          text: i18n.t('Nodes with the selected roles will be affected.'),
          fields: [
            {
              key: 'categories',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Click to add a role'),
                trackBy: 'value',
                label: 'text',
                multiple: true,
                clearOnSelect: false,
                closeOnSelect: false,
                options: roles.map(role => { return { value: role.id, text: role.id } })
              }
            }
          ]
        },
        {
          label: i18n.t('Networks on which to do SSO'),
          text: i18n.t('Comma delimited list of networks on which the SSO applies.\nFormat : 192.168.0.0/24'),
          fields: [
            {
              key: 'networks',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Cache updates'),
          text: i18n.t('Enable this to debounce updates to the Firewall.\nBy default, PacketFence will send a SSO on every DHCP request for every device. Enabling this enables "sleep" periods during which the update is not sent if the informations stay the same.'),
          fields: [
            {
              key: 'cache_updates',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Cache timeout'),
          text: i18n.t('Adjust the "Cache timeout" to half the expiration delay in your firewall.\nYour DHCP renewal interval should match this value.'),
          fields: [
            {
              key: 'cache_timeout',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              },
              validators: {
                [i18n.t('Positive numbers only.')]: numeric,
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Username format'),
          text: i18n.t('Defines how to format the username that is sent to your firewall. $username represents the username and $realm represents the realm of your user if applicable. $pf_username represents the unstripped username as it is stored in the PacketFence database. If left empty, it will use the username as stored in PacketFence (value of $pf_username).'),
          fields: [
            {
              key: 'username_format',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Default realm'),
          text: i18n.t('The default realm to be used while formatting the username when no realm can be extracted from the username.'),
          fields: [
            {
              key: 'default_realm',
              component: pfFormInput,
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

export const pfConfigurationFirewallViewDefaults = (context = {}) => {
  const {
    firewallType = null
  } = context
  switch (firewallType) {
    case 'BarracudaNG':
      return {
        port: 22,
        username_format: '$pf_username'
      }
    case 'Checkpoint':
      return {
        port: 1813,
        username_format: '$pf_username'
      }
    case 'FortiGate':
      return {
        port: 1813,
        username_format: '$pf_username'
      }
    case 'Iboss':
      return {
        password: 'XS832CF2A',
        port: 8015,
        nac_name: 'PacketFence',
        username_format: '$pf_username'
      }
    case 'JuniperSRX':
      return {
        port: 8443,
        username_format: '$pf_username'
      }
    case 'PaloAlto':
      return {
        vsys: 1,
        transport: 'http',
        port: 443,
        username_format: '$pf_username'
      }
    case 'WatchGuard':
      return {
        port: 1813,
        username_format: '$pf_username'
      }
    case 'JSONRPC':
      return {
        port: 9090,
        username_format: '$pf_username'
      }
    default:
      return {}
  }
}

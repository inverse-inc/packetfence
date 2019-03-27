import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasFirewalls,
  firewallExists
} from '@/globals/pfValidators'

const { required } = require('vuelidate/lib/validators')

export const pfConfigurationFirewallsListColumns = [
  {
    key: 'id',
    label: i18n.t('Hostname or IP'),
    sortable: true,
    visible: true
  },
  {
    key: 'type',
    label: i18n.t('Firewall Type'),
    sortable: true,
    visible: true
  },
  {
    key: 'port',
    label: i18n.t('Port'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    sortable: false,
    visible: true,
    locked: true
  }
]

export const pfConfigurationFirewallsListFields = [
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
    options: {
      meta = {}
    }
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
                ...pfConfigurationAttributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'id'),
                ...{
                  [i18n.t('Firewall exists.')]: not(and(required, conditional(isNew || isClone), hasFirewalls, firewallExists))
                }
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'username'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'username')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'password'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'password')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'password'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'password')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'port'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'port')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'vsys'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'vsys')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'transport'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'transport')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'port'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'port')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'password'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'password')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'nac_name'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'nac_name')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'categories'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'categories')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'networks'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'networks')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'cache_timeout'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'cache_timeout')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'username_format'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'username_format')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'default_realm'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'default_realm')
            }
          ]
        }
      ]
    }
  ]
}

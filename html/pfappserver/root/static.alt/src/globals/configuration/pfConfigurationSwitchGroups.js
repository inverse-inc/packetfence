import i18n from '@/utils/locale'
import pfFieldTypeValue from '@/components/pfFieldTypeValue'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  or,
  conditional,
  isMacAddress,
  isPort,
  limitSiblingFields,
  restrictAllSiblingFields,
  hasSwitchGroups,
  switchGroupExists
} from '@/globals/pfValidators'
import SwitchGroupViewMembers from '../../views/Configuration/_components/SwitchGroupViewMembers'

const {
  required,
  maxLength
} = require('vuelidate/lib/validators')

export const pfConfigurationSwitchGroupsListColumns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'description',
    label: i18n.t('Description'),
    sortable: true,
    visible: true
  },
  {
    key: 'type',
    label: i18n.t('Type'),
    sortable: true,
    visible: true
  },
  {
    key: 'mode',
    label: i18n.t('Mode'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const pfConfigurationSwitchGroupsListFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'description',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'mode',
    text: i18n.t('Mode'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'type',
    text: i18n.t('Type'),
    types: [conditionType.SUBSTRING]
  }
]

export const pfConfigurationSwitchGroupsListConfig = (context = {}) => {
  return {
    columns: pfConfigurationSwitchGroupsListColumns,
    fields: pfConfigurationSwitchGroupsListFields,
    rowClickRoute (item, index) {
      return { name: 'switch_group', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/switch_groups',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'description', op: 'contains', value: null },
            { field: 'type', op: 'contains', value: null },
            { field: 'mode', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'switch_groups' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'description', op: 'contains', value: quickCondition },
              { field: 'type', op: 'contains', value: quickCondition },
              { field: 'mode', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const pfConfigurationSwitchGroupActions = {
  always: {
    value: 'always',
    text: i18n.t('Always'),
    types: [fieldType.NONE],
    validators: {
      type: {
        /* Don't allow elsewhere */
        [i18n.t('Duplicate condition.')]: limitSiblingFields(['type', 'value'])
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
        [i18n.t('Invalid Port Number.')]: isPort,
        /* Don't allow duplicates */
        [i18n.t('Duplicate Port.')]: limitSiblingFields(['type', 'value'])
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
        [i18n.t('Invalid MAC address.')]: isMacAddress,
        /* Don't allow duplicates */
        [i18n.t('Duplicate MAC address.')]: limitSiblingFields(['type', 'value'])
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
        [i18n.t('Value required.')]: required,
        [i18n.t('Maximum 255 characters.')]: maxLength(255),
        /* Don't allow duplicates */
        [i18n.t('Duplicate SSID.')]: limitSiblingFields(['type', 'value'])
      }
    }
  }
}

export const pfConfigurationSwitchGroupViewFields = (context = {}) => {
  let {
    id = null,
    isNew = false,
    isClone = false,
    options: {
      meta = {}
    },
    form = {},
    roles = [] // all roles
  } = context

  return [
    {
      tab: i18n.t('Definition'),
      fields: [
        {
          label: i18n.t('Group name'),
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
                ...pfConfigurationValidatorsFromMeta(meta, 'id', 'ID'),
                ...{
                  [i18n.t('Switch Group exists.')]: not(and(required, conditional(isNew || isClone), hasSwitchGroups, switchGroupExists))
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Description'),
          fields: [
            {
              key: 'description',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'description'),
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'description', i18n.t('Description')),
                ...{
                  [i18n.t('Description required.')]: or(required, conditional(form.id === 'default'))
                }
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
                ...pfConfigurationAttributesFromMeta(meta, 'type'),
                ...{
                  groupLabel: 'group',
                  groupValues: 'options'
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'type', i18n.t('Type'))
            }
          ]
        },
        {
          label: i18n.t('Mode'),
          fields: [
            {
              key: 'mode',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'mode'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'mode', i18n.t('Mode'))
            }
          ]
        },
        {
          label: i18n.t('Deauthentication Method'),
          fields: [
            {
              key: 'deauthMethod',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'deauthMethod'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'deauthMethod', i18n.t('Method'))
            }
          ]
        },
        {
          label: i18n.t('Use CoA'),
          text: i18n.t('Use CoA when available to deauthenticate the user. When disabled, RADIUS Disconnect will be used instead if it is available.'),
          fields: [
            {
              key: 'useCoA',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        {
          label: i18n.t('CLI Access Enabled'),
          text: i18n.t('Allow this switch to use PacketFence as a RADIUS server for CLI access.'),
          fields: [
            {
              key: 'cliAccess',
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
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
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'dynamic', unchecked: 'static' }
              },
              listeners: {
                checked: (value) => {
                  form.uplink = null // clear uplink
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Static Uplinks'),
          text: i18n.t('Comma-separated list of the switch uplinks.'),
          if: (form.uplink_dynamic !== 'dynamic'),
          fields: [
            {
              key: 'uplink',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'uplink'),
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'uplink', i18n.t('Uplinks')),
                ...{
                  [i18n.t('Uplinks required.')]: or(required, conditional(form.uplink_dynamic === 'dynamic'))
                }
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'controllerIp'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'controllerIp', 'IP')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'disconnectPort'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'disconnectPort', i18n.t('Port'))
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'coaPort'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'coaPort', i18n.t('Port'))
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
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        ...[
          { id: 'registration', label: i18n.t('registration') },
          { id: 'isolation', label: i18n.t('isolation') },
          { id: 'inline', label: i18n.t('inline') },
          ...roles
        ].map(role => {
          return {
            label: role.label || role.id,
            if: (form.VlanMap === 'Y'),
            fields: [
              {
                key: `${role.id}Vlan`,
                component: pfFormInput,
                attrs: pfConfigurationAttributesFromMeta(meta, `${role.id}Vlan`),
                validators: pfConfigurationValidatorsFromMeta(meta, `${role.id}Vlan`, 'VLAN')
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
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        ...[
          { id: 'registration', label: i18n.t('registration') },
          { id: 'isolation', label: i18n.t('isolation') },
          { id: 'inline', label: i18n.t('inline') },
          ...roles
        ].map(role => {
          return {
            label: role.label || role.id,
            if: (form.RoleMap === 'Y'),
            fields: [
              {
                key: `${role.id}Role`,
                component: pfFormInput,
                attrs: pfConfigurationAttributesFromMeta(meta, `${role.id}Role`),
                validators: pfConfigurationValidatorsFromMeta(meta, `${role.id}Role`, i18n.t('Role'))
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
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        ...[
          { id: 'registration', label: i18n.t('registration') },
          { id: 'isolation', label: i18n.t('isolation') },
          { id: 'inline', label: i18n.t('inline') },
          ...roles
        ].map(role => {
          return {
            label: role.label || role.id,
            if: (form.AccessListMap === 'Y'),
            fields: [
              {
                key: `${role.id}AccessList`,
                component: pfFormTextarea,
                attrs: {
                  ...pfConfigurationAttributesFromMeta(meta, `${role.id}AccessList`),
                  ...{
                    rows: 3
                  }
                },
                validators: pfConfigurationValidatorsFromMeta(meta, `${role.id}AccessList`, i18n.t('List'))
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
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'Y', unchecked: 'N' }
              }
            }
          ]
        },
        ...[
          { id: 'registration', label: i18n.t('registration') },
          { id: 'isolation', label: i18n.t('isolation') },
          { id: 'inline', label: i18n.t('inline') },
          ...roles
        ].map(role => {
          return {
            label: role.label || role.id,
            if: (form.UrlMap === 'Y'),
            fields: [
              {
                key: `${role.id}Url`,
                component: pfFormInput,
                attrs: pfConfigurationAttributesFromMeta(meta, `${role.id}Url`),
                validators: pfConfigurationValidatorsFromMeta(meta, `${role.id}Url`, 'URL')
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
                buttonLabel: i18n.t('Add Condition'),
                sortable: false,
                field: {
                  component: pfFieldTypeValue,
                  attrs: {
                    typeLabel: i18n.t('Select condition type'),
                    valueLabel: i18n.t('Select condition value'),
                    fields: [
                      pfConfigurationSwitchGroupActions.always,
                      pfConfigurationSwitchGroupActions.port,
                      pfConfigurationSwitchGroupActions.mac,
                      pfConfigurationSwitchGroupActions.ssid
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'radiusSecret'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'radiusSecret', i18n.t('Secret'))
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPVersion'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPVersion', i18n.t('Version'))
            }
          ]
        },
        {
          label: i18n.t('Community Read'),
          fields: [
            {
              key: 'SNMPCommunityRead',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPCommunityRead'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPCommunityRead')
            }
          ]
        },
        {
          label: i18n.t('Community Write'),
          fields: [
            {
              key: 'SNMPCommunityWrite',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPCommunityWrite'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPCommunityWrite')
            }
          ]
        },
        {
          label: i18n.t('Engine ID'),
          fields: [
            {
              key: 'SNMPEngineID',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPEngineID'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPEngineID')
            }
          ]
        },
        {
          label: i18n.t('User Name Read'),
          fields: [
            {
              key: 'SNMPUserNameRead',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPUserNameRead'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPUserNameRead')
            }
          ]
        },
        {
          label: i18n.t('Auth Protocol Read'),
          fields: [
            {
              key: 'SNMPAuthProtocolRead',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPAuthProtocolRead'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthProtocolRead')
            }
          ]
        },
        {
          label: i18n.t('Auth Password Read'),
          fields: [
            {
              key: 'SNMPAuthPasswordRead',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPAuthPasswordRead'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthPasswordRead')
            }
          ]
        },
        {
          label: i18n.t('Priv Protocol Read'),
          fields: [
            {
              key: 'SNMPPrivProtocolRead',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPPrivProtocolRead'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivProtocolRead')
            }
          ]
        },
        {
          label: i18n.t('Priv Password Read'),
          fields: [
            {
              key: 'SNMPPrivPasswordRead',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPPrivPasswordRead'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivPasswordRead')
            }
          ]
        },
        {
          label: i18n.t('User Name Write'),
          fields: [
            {
              key: 'SNMPUserNameWrite',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPUserNameWrite'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPUserNameWrite')
            }
          ]
        },
        {
          label: i18n.t('Auth Protocol Write'),
          fields: [
            {
              key: 'SNMPAuthProtocolWrite',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPAuthProtocolWrite'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthProtocolWrite')
            }
          ]
        },
        {
          label: i18n.t('Auth Password Write'),
          fields: [
            {
              key: 'SNMPAuthPasswordWrite',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPAuthPasswordWrite'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthPasswordWrite')
            }
          ]
        },
        {
          label: i18n.t('Priv Protocol Write'),
          fields: [
            {
              key: 'SNMPPrivProtocolWrite',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPPrivProtocolWrite'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivProtocolWrite')
            }
          ]
        },
        {
          label: i18n.t('Priv Password Write'),
          fields: [
            {
              key: 'SNMPPrivPasswordWrite',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPPrivPasswordWrite'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivPasswordWrite')
            }
          ]
        },
        {
          label: i18n.t('Version Trap'),
          fields: [
            {
              key: 'SNMPVersionTrap',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPVersionTrap'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPVersionTrap')
            }
          ]
        },
        {
          label: i18n.t('Community Trap'),
          fields: [
            {
              key: 'SNMPCommunityTrap',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPCommunityTrap'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPCommunityTrap')
            }
          ]
        },
        {
          label: i18n.t('User Name Trap'),
          fields: [
            {
              key: 'SNMPUserNameTrap',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPUserNameTrap'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPUserNameTrap')
            }
          ]
        },
        {
          label: i18n.t('Auth Protocol Trap'),
          fields: [
            {
              key: 'SNMPAuthProtocolTrap',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPAuthProtocolTrap'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthProtocolTrap')
            }
          ]
        },
        {
          label: i18n.t('Auth Password Trap'),
          fields: [
            {
              key: 'SNMPAuthPasswordTrap',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPAuthPasswordTrap'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthPasswordTrap')
            }
          ]
        },
        {
          label: i18n.t('Priv Protocol Trap'),
          fields: [
            {
              key: 'SNMPPrivProtocolTrap',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPPrivProtocolTrap'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivProtocolTrap')
            }
          ]
        },
        {
          label: i18n.t('Priv Password Trap'),
          fields: [
            {
              key: 'SNMPPrivPasswordTrap',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'SNMPPrivPasswordTrap'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivPasswordTrap')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'macSearchesMaxNb'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'macSearchesMaxNb', i18n.t('Max'))
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'macSearchesSleepInterval'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'macSearchesSleepInterval', i18n.t('Interval'))
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'cliTransport'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'cliTransport', i18n.t('Transport'))
            }
          ]
        },
        {
          label: i18n.t('Username'),
          fields: [
            {
              key: 'cliUser',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'cliUser'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'cliUser', i18n.t('Username'))
            }
          ]
        },
        {
          label: i18n.t('Password'),
          fields: [
            {
              key: 'cliPwd',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'cliPwd'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'cliPwd', i18n.t('Password'))
            }
          ]
        },
        {
          label: i18n.t('Enable Password'),
          fields: [
            {
              key: 'cliEnablePwd',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'cliEnablePwd'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'cliEnablePwd', i18n.t('Password'))
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'wsTransport'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'wsTransport', i18n.t('Transport'))
            }
          ]
        },
        {
          label: i18n.t('Username'),
          fields: [
            {
              key: 'wsUser',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'wsUser'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'wsUser', i18n.t('Username'))
            }
          ]
        },
        {
          label: i18n.t('Password'),
          fields: [
            {
              key: 'wsPwd',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'wsPwd'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'wsPwd', i18n.t('Password'))
            }
          ]
        }
      ]
    },
    {
      if: (!isNew && !isClone),
      tab: i18n.t('Members'),
      fields: [
        {
          fields: [
            {
              component: SwitchGroupViewMembers,
              attrs: {
                id,
                members: form.members,
                class: null // suppress default styles
              }
            }
          ]
        }
      ]
    }
  ]
}

/*
export const pfConfigurationSwitchGroupViewPlaceholders = (context = {}) => {
  // TODO: replace with inherited defaults from conf/switches.conf.defaults
  return {
    vlans: '1,2,3,4,5',
    normalVlan: '1',
    registrationVlan: '2',
    isolationVlan: '3',
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

export const pfConfigurationSwitchGroupViewDefaults = (context = {}) => {
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
*/

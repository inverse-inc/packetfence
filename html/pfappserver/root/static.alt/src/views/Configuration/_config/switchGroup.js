import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import {
  and,
  not,
  or,
  conditional,
  hasSwitchGroups,
  switchGroupExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'
import {
  columns,
  fields,
  supports,
  viewFields
} from './switch'
import SwitchGroupViewMembers from '@/views/Configuration/_components/SwitchGroupViewMembers'

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
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

export const view = (form = {}, meta = {}) => {
  const {
    id,
    members = []
  } = form
  const {
    isNew = false,
    isClone = false,
    advancedMode = false
  } = meta
  return [
    {
      tab: i18n.t('Definition'),
      rows: [
        {
          label: i18n.t('Group name'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              }
            }
          ]
        },
        viewFields.description(form, meta),
        viewFields.type(form, meta),
        viewFields.mode(form, meta),
        viewFields.group(form, meta),
        viewFields.deauthMethod(form, meta),
        viewFields.useCoA(form, meta),
        viewFields.cliAccess(form, meta),
        viewFields.ExternalPortalEnforcement(form, meta),
        viewFields.VoIPEnabled(form, meta),
        viewFields.VoIPLLDPDetect(form, meta),
        viewFields.VoIPCDPDetect(form, meta),
        viewFields.VoIPDHCPDetect(form, meta),
        viewFields.uplink_dynamic(form, meta),
        viewFields.uplink(form, meta),
        viewFields.controllerIp(form, meta),
        viewFields.disconnectPort(form, meta),
        viewFields.coaPort(form, meta)
      ]
    },
    {
      tab: i18n.t('Roles'),
      rows: [
        {
          if: advancedMode || supports(form, meta, ['RadiusDynamicVlanAssignment']),
          label: i18n.t('Role mapping by VLAN ID'),
          labelSize: 'lg'
        },
        viewFields.VlanMap(form, meta),
        ...viewFields.mapVlan(form, meta),
        {
          if: advancedMode || supports(form, meta, ['RoleBasedEnforcement']),
          label: i18n.t('Role mapping by Switch Role'),
          labelSize: 'lg'
        },
        viewFields.RoleMap(form, meta),
        ...viewFields.mapRole(form, meta),
        {
          if: advancedMode || supports(form, meta, ['AccessListBasedEnforcement']),
          label: i18n.t('Role mapping by Access List'),
          labelSize: 'lg'
        },
        viewFields.AccessListMap(form, meta),
        ...viewFields.mapAccessList(form, meta),
        {
          if: advancedMode || supports(form, meta, ['ExternalPortal']),
          label: i18n.t('Role mapping by Web Auth URL'),
          labelSize: 'lg'
        },
        viewFields.UrlMap(form, meta),
        ...viewFields.mapUrl(form, meta)
      ]
    },
    {
      tab: i18n.t('Inline'),
      rows: [
        viewFields.inlineTrigger(form, meta)
      ]
    },
    {
      if: supports(form, meta, ['WiredMacAuth', 'WiredDot1x', 'WirelessMacAuth', 'WirelessDot1x']),
      tab: i18n.t('RADIUS'),
      rows: [
        viewFields.radiusSecret(form, meta)
      ]
    },
    {
      tab: i18n.t('SNMP'),
      rows: [
        viewFields.SNMPVersion(form, meta),
        viewFields.SNMPCommunityRead(form, meta),
        viewFields.SNMPCommunityWrite(form, meta),
        viewFields.SNMPEngineID(form, meta),
        viewFields.SNMPUserNameRead(form, meta),
        viewFields.SNMPAuthProtocolRead(form, meta),
        viewFields.SNMPAuthPasswordRead(form, meta),
        viewFields.SNMPPrivProtocolRead(form, meta),
        viewFields.SNMPPrivPasswordRead(form, meta),
        viewFields.SNMPUserNameWrite(form, meta),
        viewFields.SNMPAuthProtocolWrite(form, meta),
        viewFields.SNMPAuthPasswordWrite(form, meta),
        viewFields.SNMPPrivProtocolWrite(form, meta),
        viewFields.SNMPPrivPasswordWrite(form, meta),
        viewFields.SNMPVersionTrap(form, meta),
        viewFields.SNMPCommunityTrap(form, meta),
        viewFields.SNMPUserNameTrap(form, meta),
        viewFields.SNMPAuthProtocolTrap(form, meta),
        viewFields.SNMPAuthPasswordTrap(form, meta),
        viewFields.SNMPPrivProtocolTrap(form, meta),
        viewFields.SNMPPrivPasswordTrap(form, meta),
        viewFields.macSearchesMaxNb(form, meta),
        viewFields.macSearchesSleepInterval(form, meta)
      ]
    },
    {
      tab: i18n.t('CLI'),
      rows: [
        viewFields.cliTransport(form, meta),
        viewFields.cliUser(form, meta),
        viewFields.cliPwd(form, meta),
        viewFields.cliEnablePwd(form, meta)
      ]
    },
    {
      tab: i18n.t('Web Services'),
      rows: [
        viewFields.wsTransport(form, meta),
        viewFields.wsUser(form, meta),
        viewFields.wsPwd(form, meta)
      ]
    },
    {
      if: (!isNew && !isClone),
      tab: i18n.t('Members'),
      rows: [
        {
          cols: [
            {
              component: SwitchGroupViewMembers,
              attrs: {
                id,
                members,
                class: null // suppress default styles
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    id,
    uplink_dynamic: uplinkDynamic,
    VlanMap,
    RoleMap,
    AccessListMap,
    UrlMap,
    inlineTrigger = []
  } = form
  const {
    isNew = false,
    isClone = false,
    roles = [],
    advancedMode = false
  } = meta
  return {
    ...{
      ...[
        { id: 'registration', label: i18n.t('registration') },
        { id: 'isolation', label: i18n.t('isolation') },
        { id: 'macDetection', label: i18n.t('macDetection') },
        { id: 'inline', label: i18n.t('inline') },
        ...roles
      ].reduce((validators, role) => {
        return {
          ...validators,
          ...{
            ...((advancedMode || (supports(form, meta, ['RadiusDynamicVlanAssignment']) && (VlanMap === 'Y' || (!VlanMap && placeholder(meta, 'VlanMap') === 'Y'))))
              ? { [`${role.id}Vlan`]: pfConfigurationValidatorsFromMeta(meta, `${role.id}Vlan`, 'VLAN') }
              : {}
            ),
            ...((advancedMode || (supports(form, meta, ['RoleBasedEnforcement']) && (RoleMap === 'Y' || (!RoleMap && placeholder(meta, 'RoleMap') === 'Y'))))
              ? { [`${role.id}Role`]: pfConfigurationValidatorsFromMeta(meta, `${role.id}Role`, i18n.t('Role')) }
              : {}
            ),
            ...((advancedMode || (supports(form, meta, ['AccessListBasedEnforcement']) && (AccessListMap === 'Y' || (!AccessListMap && placeholder(meta, 'AccessListMap') === 'Y'))))
              ? { [`${role.id}AccessList`]: pfConfigurationValidatorsFromMeta(meta, `${role.id}AccessList`, i18n.t('List')) }
              : {}
            ),
            ...((advancedMode || (supports(form, meta, ['ExternalPortal']) && (UrlMap === 'Y' || (!UrlMap && placeholder(meta, 'UrlMap') === 'Y'))))
              ? { [`${role.id}Url`]: pfConfigurationValidatorsFromMeta(meta, `${role.id}Url`, 'URL') }
              : {}
            )
          }
        }
      }, {})
    },
    ...{
      ...(((advancedMode || supports(form, meta, ['WiredMacAuth', 'WiredDot1x'])) && ((uplinkDynamic && uplinkDynamic !== 'dynamic') || (!uplinkDynamic && placeholder(meta, 'uplink_dynamic') !== 'dynamic')))
        ? {
          uplink: {
            ...pfConfigurationValidatorsFromMeta(meta, 'uplink', i18n.t('Uplinks')),
            ...{
              [i18n.t('Uplinks required.')]: required
            }
          }
        }
        : {}
      ),
      ...((advancedMode || supports(form, meta, ['WirelessMacAuth', 'WirelessDot1x']))
        ? {
          controllerIp: pfConfigurationValidatorsFromMeta(meta, 'controllerIp', 'IP')
        }
        : {}
      ),
      ...((advancedMode || supports(form, meta, ['WiredMacAuth', 'WiredDot1x', 'WirelessMacAuth', 'WirelessDot1x']))
        ? {
          disconnectPort: pfConfigurationValidatorsFromMeta(meta, 'disconnectPort', i18n.t('Port'))
        }
        : {}
      ),
      ...((advancedMode || supports(form, meta, ['WiredMacAuth', 'WiredDot1x', 'WirelessMacAuth', 'WirelessDot1x']))
        ? {
          coaPort: pfConfigurationValidatorsFromMeta(meta, 'coaPort', i18n.t('Port'))
        }
        : {}
      ),
      ...((advancedMode || supports(form, meta, ['WiredMacAuth', 'WiredDot1x', 'WirelessMacAuth', 'WirelessDot1x', 'VPN']))
        ? {
          radiusSecret: pfConfigurationValidatorsFromMeta(meta, 'radiusSecret', i18n.t('Secret'))
        }
        : {}
      )
    },
    ...{
      id: {
        ...pfConfigurationValidatorsFromMeta(meta, 'id', 'ID'),
        ...{
          [i18n.t('Switch Group exists.')]: not(and(required, conditional(isNew || isClone), hasSwitchGroups, switchGroupExists))
        }
      },
      description:
      {
        ...pfConfigurationValidatorsFromMeta(meta, 'description', i18n.t('Description')),
        ...{
          [i18n.t('Description required.')]: or(required, conditional(id === 'default'))
        }
      },
      inlineTrigger: {
        ...(inlineTrigger || []).map(_inlineTrigger => { // index based inlineTrigger validators
          if (_inlineTrigger) {
            const { type } = _inlineTrigger
            if (type) {
              const { [type]: { validators: { type: typeValidators = {}, value: valueValidators = {} } = {} } = {} } = inlineTriggers
              if (validators) {
                return {
                  type: {
                    ...{
                      [i18n.t('Trigger condition.')]: required,
                      [i18n.t('Duplicate condition.')]: conditional((type) => !(inlineTrigger.filter(trigger => trigger && trigger.type === type).length > 1)),
                      [i18n.t('Condition conflicts with "Always".')]: conditional((type) => !(type !== 'always' && inlineTrigger.filter(trigger => trigger && trigger.type === 'always').length > 0))
                    },
                    ...typeValidators
                  },
                  value: {
                    ...{
                      [i18n.t('Value required.')]: conditional((value) => !(type !== 'always' && !value)),
                      [i18n.t('Maximum 255 characters.')]: maxLength(255)
                    },
                    ...valueValidators
                  }
                }
              }
            }
          }
          return {
            type: {
              [i18n.t('Condition required.')]: required
            }
          }
        })
      },
      type: pfConfigurationValidatorsFromMeta(meta, 'type', i18n.t('Type')),
      mode: pfConfigurationValidatorsFromMeta(meta, 'mode', i18n.t('Mode')),
      group: pfConfigurationValidatorsFromMeta(meta, 'group', i18n.t('Group')),
      deauthMethod: pfConfigurationValidatorsFromMeta(meta, 'deauthMethod', i18n.t('Method')),
      SNMPVersion: pfConfigurationValidatorsFromMeta(meta, 'SNMPVersion', i18n.t('Version')),
      SNMPCommunityRead: pfConfigurationValidatorsFromMeta(meta, 'SNMPCommunityRead'),
      SNMPCommunityWrite: pfConfigurationValidatorsFromMeta(meta, 'SNMPCommunityWrite'),
      SNMPEngineID: pfConfigurationValidatorsFromMeta(meta, 'SNMPEngineID'),
      SNMPUserNameRead: pfConfigurationValidatorsFromMeta(meta, 'SNMPUserNameRead'),
      SNMPAuthProtocolRead: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthProtocolRead'),
      SNMPAuthPasswordRead: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthPasswordRead'),
      SNMPPrivProtocolRead: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivProtocolRead'),
      SNMPPrivPasswordRead: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivPasswordRead'),
      SNMPUserNameWrite: pfConfigurationValidatorsFromMeta(meta, 'SNMPUserNameWrite'),
      SNMPAuthProtocolWrite: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthProtocolWrite'),
      SNMPAuthPasswordWrite: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthPasswordWrite'),
      SNMPPrivProtocolWrite: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivProtocolWrite'),
      SNMPPrivPasswordWrite: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivPasswordWrite'),
      SNMPVersionTrap: pfConfigurationValidatorsFromMeta(meta, 'SNMPVersionTrap'),
      SNMPCommunityTrap: pfConfigurationValidatorsFromMeta(meta, 'SNMPCommunityTrap'),
      SNMPUserNameTrap: pfConfigurationValidatorsFromMeta(meta, 'SNMPUserNameTrap'),
      SNMPAuthProtocolTrap: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthProtocolTrap'),
      SNMPAuthPasswordTrap: pfConfigurationValidatorsFromMeta(meta, 'SNMPAuthPasswordTrap'),
      SNMPPrivProtocolTrap: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivProtocolTrap'),
      SNMPPrivPasswordTrap: pfConfigurationValidatorsFromMeta(meta, 'SNMPPrivPasswordTrap'),
      macSearchesMaxNb: pfConfigurationValidatorsFromMeta(meta, 'macSearchesMaxNb', i18n.t('Max')),
      macSearchesSleepInterval: pfConfigurationValidatorsFromMeta(meta, 'macSearchesSleepInterval', i18n.t('Interval')),
      cliTransport: pfConfigurationValidatorsFromMeta(meta, 'cliTransport', i18n.t('Transport')),
      cliUser: pfConfigurationValidatorsFromMeta(meta, 'cliUser', i18n.t('Username')),
      cliPwd: pfConfigurationValidatorsFromMeta(meta, 'cliPwd', i18n.t('Password')),
      cliEnablePwd: pfConfigurationValidatorsFromMeta(meta, 'cliEnablePwd', i18n.t('Password')),
      wsTransport: pfConfigurationValidatorsFromMeta(meta, 'wsTransport', i18n.t('Transport')),
      wsUser: pfConfigurationValidatorsFromMeta(meta, 'wsUser', i18n.t('Username')),
      wsPwd: pfConfigurationValidatorsFromMeta(meta, 'wsPwd', i18n.t('Password'))
    }
  }
}


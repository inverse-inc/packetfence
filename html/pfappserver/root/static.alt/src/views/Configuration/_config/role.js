import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormTextarea from '@/components/pfFormTextarea'
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
  hasRoles,
  roleExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: i18n.t('Name'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'notes',
    label: i18n.t('Description'),
    sortable: true,
    visible: true
  },
  {
    key: 'max_nodes_per_pid',
    label: i18n.t('Max nodes per user'),
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
    value: 'notes',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  }
]

export const reasons = {
  ADMIN_ROLES_IN_USE: i18n.t('Admin Roles'),
  BILLING_TIERS_IN_USE: i18n.t('Billing Tiers'),
  FIREWALL_SSO_IN_USE: i18n.t('Firewall SSO.'),
  NODE_BYPASS_ROLE_ID_IN_USE: i18n.t('Node Bypass Role'),
  NODE_CATEGORY_ID_IN_USE: i18n.t('Node Category'),
  PASSWORD_CATEGORY_IN_USE: i18n.t('Password Category'),
  PROVISIONING_IN_USE: i18n.t('Provisioning'),
  SCAN_IN_USE: i18n.t('Scans'),
  SECURITY_EVENTS_IN_USE: i18n.t('Security Events'),
  SELFSERVICE_IN_USE: i18n.t('Self Service'),
  SWITCH_IN_USE: i18n.t('Switches')
}

export const config = (context = {}) => {
  const {
    parentId = null
  } = context
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'role', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by name or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/roles',
      searchApiEndpointOnly: true, // always use `/search` endpoint
      defaultSortKeys: ['id', 'not_deletable'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'parent', op: 'equals', value: (parentId || null) }
          ]
        }]
      },
      defaultRoute: { name: 'roles' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          ...((!quickCondition.trim())
            ? [{ op: 'or', values: [{ field: 'parent', op: 'equals', value: (parentId || null) }] }]
            : []
          ),
          ...((quickCondition.trim())
            ? [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: quickCondition.trim() },
                { field: 'notes', op: 'contains', value: quickCondition.trim() }
              ]
            }]
            : []
          )
        ]
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
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('Name'),
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
          label: i18n.t('Description'),
          cols: [
            {
              namespace: 'notes',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'notes')
            }
          ]
        },
        {
          label: i18n.t('Max nodes per user'),
          text: i18n.t('The maximum number of nodes a user having this role can register. A number of 0 means unlimited number of devices.'),
          cols: [
            {
              namespace: 'max_nodes_per_pid',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'max_nodes_per_pid')
            }
          ]
        },
        {
          label: i18n.t('Parent'),
          text: i18n.t('Parent Role.'),
          cols: [
            {
              namespace: 'parent',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'parent')
            }
          ]
        },
        {
          label: i18n.t('Include Parent ACLs'),
          text: i18n.t(`Include parents ACLs`),
          cols: [
            {
              namespace: 'include_parent_acls',
              component: pfFormRangeToggle,
              attrs: {
                ...attributesFromMeta(meta, 'include_parent_acls'),
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Fingerbank Dynamic ACLs'),
          text: i18n.t(`Use the Fingerbank dynamic ACLS`),
          cols: [
            {
              namespace: 'fingerbank_dynamic_access_list',
              component: pfFormRangeToggle,
              attrs: {
                ...attributesFromMeta(meta, 'fingerbank_dynamic_access_list'),
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('ACLs'),
          text: i18n.t('Access Control Lists.'),
          cols: [
            {
              namespace: 'acls',
              component: pfFormTextarea,
              attrs: attributesFromMeta(meta, 'acls')
            }
          ]
        },
        {
          label: i18n.t('Inherit VLAN'),
          text: i18n.t('Inherit VLAN from parent if none is found'),
          cols: [
            {
              namespace: 'inherit_vlan',
              component: pfFormRangeToggle,
              attrs: {
                ...attributesFromMeta(meta, 'inherit_vlan'),
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (_, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', i18n.t('Name')),
      ...{
        [i18n.t('Role exists.')]: not(and(required, conditional(isNew || isClone), hasRoles, roleExists))
      }
    },
    notes: validatorsFromMeta(meta, 'notes', i18n.t('Description')),
    max_nodes_per_pid: validatorsFromMeta(meta, 'max_nodes_per_pid', i18n.t('Max'))
  }
}

import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

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
      defaultSortKeys: ['id', 'not_deletable', 'children'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'parent_id', op: 'equals', value: (parentId || null) }
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
            ? [{ op: 'or', values: [{ field: 'parent_id', op: 'equals', value: (parentId || null) }] }]
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

import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export const columns = [
  {
    key: 'id',
    label: i18n.t('Name'),
    required: true,
    sortable: true,
    visible: true,
    searchable: true
  },
  {
    key: 'notes',
    label: i18n.t('Description'),
    sortable: true,
    visible: true,
    searchable: true
  },
  {
    key: 'max_nodes_per_pid',
    label: i18n.t('Max nodes per user'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    locked: true
  },
  {
    key: 'children',
    required: true
  },
  {
    key: 'parent_id',
    required: true
  },
  {
    key: 'not_deletable',
    required: true
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
  },
  {
    value: 'parent_id',
    text: i18n.t('Parent Role'),
    types: [conditionType.ROLE]
  }
]

// backend reports 1+ reason(s) for delete failure.
//  map friendly reasons
export const reasons = {
  ADMIN_ROLES_IN_USE: i18n.t('Admin Roles'),
  BILLING_TIERS_IN_USE: i18n.t('Billing Tiers'),
  FIREWALL_SSO_IN_USE: i18n.t('Firewall SSO'),
  NODE_BYPASS_ROLE_ID_IN_USE: i18n.t('Node Bypass Role'),
  NODE_CATEGORY_ID_IN_USE: i18n.t('Node Category'),
  PASSWORD_CATEGORY_IN_USE: i18n.t('Password Category'),
  PROVISIONING_IN_USE: i18n.t('Provisioning'),
  SCAN_IN_USE: i18n.t('Scans'),
  SECURITY_EVENTS_IN_USE: i18n.t('Security Events'),
  SELFSERVICE_IN_USE: i18n.t('Self Service'),
  SWITCH_IN_USE: i18n.t('Switches')
}

import i18n from '@/utils/locale'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'

export const pfConfigurationColumns = {
  admin_strip_username: {
    key: 'admin_strip_username',
    label: i18n.t('Strip Admin'),
    sortable: true,
    visible: true
  },
  class: {
    key: 'class',
    label: i18n.t('Class'),
    sortable: true,
    visible: true
  },
  description: {
    key: 'description',
    label: i18n.t('Description'),
    sortable: true,
    visible: true
  },
  id: {
    key: 'id',
    label: i18n.t('Name'),
    sortable: true,
    visible: true
  },
  ip: {
    key: 'ip',
    label: i18n.t('IP Address'),
    sortable: true,
    visible: true
  },
  max_nodes_per_pid: {
    key: 'max_nodes_per_pid',
    label: i18n.t('Max nodes per user'),
    sortable: true,
    visible: true
  },
  notes: {
    key: 'notes',
    label: i18n.t('Description'),
    sortable: true,
    visible: true
  },
  portal_strip_username: {
    key: 'portal_strip_username',
    label: i18n.t('Strip Portal'),
    sortable: true,
    visible: true
  },
  pvid: {
    key: 'pvid',
    label: i18n.t('Native VLAN'),
    sortable: true,
    visible: true
  },
  radius_strip_username: {
    key: 'radius_strip_username',
    label: i18n.t('Strip RADIUS'),
    sortable: true,
    visible: true
  },
  type: {
    key: 'type',
    label: i18n.t('Type'),
    sortable: true,
    visible: true
  },
  workgroup: {
    key: 'workgroup',
    label: i18n.t('Workgroup'),
    sortable: true,
    visible: true
  },
  /* Special columns not mapped to any real configuration */
  buttons: {
    key: 'buttons',
    label: '',
    sortable: false,
    visible: true,
    locked: true
  }
}

export const pfConfigurationColumnsAuthenticationSources = [
  pfConfigurationColumns.id,
  pfConfigurationColumns.description,
  pfConfigurationColumns.class,
  pfConfigurationColumns.type,
  pfConfigurationColumns.buttons
]

export const pfConfigurationColumnsDomains = [
  pfConfigurationColumns.id,
  pfConfigurationColumns.workgroup
]

export const pfConfigurationColumnsFloatingDevices = [
  Object.assign(pfConfigurationColumns.id, { label: i18n.t('MAC') }),
  pfConfigurationColumns.ip,
  pfConfigurationColumns.pvid
]

export const pfConfigurationColumnsRealmsList = [
  pfConfigurationColumns.id,
  pfConfigurationColumns.portal_strip_username,
  pfConfigurationColumns.admin_strip_username,
  pfConfigurationColumns.radius_strip_username
]

export const pfConfigurationColumnsRoles = [
  pfConfigurationColumns.id,
  pfConfigurationColumns.notes,
  pfConfigurationColumns.max_nodes_per_pid,
  pfConfigurationColumns.buttons
]

export const pfConfigurationFields = {
  id: {
    value: 'id',
    text: i18n.t('Name'),
    types: [conditionType.SUBSTRING]
  },
  class: {
    value: 'class',
    text: i18n.t('Class'),
    types: [conditionType.SUBSTRING]
  },
  description: {
    value: 'description',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  },
  ip: {
    value: 'ip',
    text: i18n.t('IP Address'),
    types: [conditionType.SUBSTRING]
  },
  notes: {
    value: 'notes',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  },
  type: {
    value: 'type',
    text: i18n.t('Type'),
    types: [conditionType.SUBSTRING]
  },
  workgroup: {
    value: 'workgroup',
    text: i18n.t('Workgroup'),
    types: [conditionType.SUBSTRING]
  }
}

export const pfConfigurationFieldsAuthenticationSources = [
  pfConfigurationFields.id,
  pfConfigurationFields.description,
  pfConfigurationFields.class,
  pfConfigurationFields.type
]

export const pfConfigurationFieldsDomains = [
  pfConfigurationFields.id,
  pfConfigurationFields.workgroup
]

export const pfConfigurationFieldsFloatingDevices = [
  Object.assign(pfConfigurationFields.id, { text: i18n.t('MAC') }),
  pfConfigurationFields.ip
]

export const pfConfigurationFieldsRealmsList = [
  pfConfigurationFields.id
]

export const pfConfigurationFieldsRoles = [
  pfConfigurationFields.id,
  pfConfigurationFields.notes
]

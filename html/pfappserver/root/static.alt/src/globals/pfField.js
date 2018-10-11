/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import i18n from '@/utils/locale'

export const pfFieldType = {
  NONE:                    'none',
  INTEGER:                 'integer',
  SUBSTRING:               'substring',
  DATETIME:                'datetime',
  PREFIXMULTIPLIER:        'prefixmultiplier',
  DURATION:                'duration',
  SELECTMANY:              'selectmany',
  ADMINROLE:               'adminrole',
  ROLE:                    'role',
  TENANT:                  'tenant'
}

export const pfFieldTypeValues = {}

pfFieldTypeValues[pfFieldType.ADMINROLE] = (store) => {
  return store.getters['config/adminRolesList']
}
pfFieldTypeValues[pfFieldType.ROLE] = (store) => {
  return store.getters['config/rolesList']
}
pfFieldTypeValues[pfFieldType.TENANT] = (store) => {
  return store.getters['config/tenantsList']
}
pfFieldTypeValues[pfFieldType.DURATION] = () => {
  return [
    { name: i18n.t('1 hour'), value: '1h' },
    { name: i18n.t('3 hours'), value: '3h' },
    { name: i18n.t('12 hours'), value: '12h' },
    { name: i18n.t('1 day'), value: '1D' },
    { name: i18n.t('2 days'), value: '2D' },
    { name: i18n.t('3 days'), value: '3D' },
    { name: i18n.t('5 days'), value: '5D' }
  ]
}

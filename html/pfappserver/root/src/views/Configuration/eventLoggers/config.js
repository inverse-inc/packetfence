import i18n from '@/utils/locale'

export const types = {
  syslog: i18n.t('Syslog')
}

export const typeOptions = Object.keys(types)
  .sort((a, b) => types[a].localeCompare(types[b]))
  .map(key => ({ value: key, text: types[key] }))

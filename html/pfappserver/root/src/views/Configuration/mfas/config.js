import i18n from '@/utils/locale'

export const types = {
  Akamai:     i18n.t('Akamai'),
  Akamai_bind_v2: i18n.t('Akamai Bind V2'),
}

export const typeOptions = Object.keys(types)
  .sort((a, b) => types[a].localeCompare(types[b]))
  .map(key => ({ value: key, text: types[key] }))




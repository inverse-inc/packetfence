import i18n from '@/utils/locale'

export const types = {
  Akamai:     i18n.t('Akamai'),
  OTP:        i18n.t('OTP')
}

export const typeOptions = Object.keys(types)
  .sort((a, b) => types[a].localeCompare(types[b]))
  .map(key => ({ value: key, text: types[key] }))




import i18n from '@/utils/locale'

export const types = {
  Azure:      i18n.t('Azure'),
  Google:     i18n.t('Google'),
  Intune:     i18n.t('Intune'),
}

export const typeOptions = Object.keys(types)
  .sort((a, b) => types[a].localeCompare(types[b]))
  .map(key => ({ value: key, text: types[key] }))




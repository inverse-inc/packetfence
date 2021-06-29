import i18n from '@/utils/locale'

export const types = {
  Intune:     i18n.t('Intune'),
}

export const typeOptions = Object.keys(types)
  .sort((a, b) => types[a].localeCompare(types[b]))
  .map(key => ({ value: key, text: types[key] }))




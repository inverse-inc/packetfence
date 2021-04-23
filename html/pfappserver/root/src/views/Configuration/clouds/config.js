import i18n from '@/utils/locale'

export const types = {
  BarracudaNG:      i18n.t('Azure'),
  Checkpoint:       i18n.t('Google'),
  CiscoIsePic:      i18n.t('Intune'),
}

export const typeOptions = Object.keys(types)
  .sort((a, b) => types[a].localeCompare(types[b]))
  .map(key => ({ value: key, text: types[key] }))




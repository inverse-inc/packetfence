import i18n from '@/utils/locale'

export const types = {
  nessus:   i18n.t('Nessus'),
  nessus6:  i18n.t('Nessus 6'),
  openvas:  i18n.t('OpenVAS'),
  rapid7:   i18n.t('Rapid7'),
  wmi:      i18n.t('WMI')
}

export const typeOptions = Object.keys(types)
  .sort((a, b) => types[a].localeCompare(types[b]))
  .map(key => ({ value: key, text: types[key] }))

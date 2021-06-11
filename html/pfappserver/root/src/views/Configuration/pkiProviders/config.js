import i18n from '@/utils/locale'

export const pkiProvidersTypes = {
  packetfence_local:  i18n.t('Packetfence Local'),
  packetfence_pki:    i18n.t('Packetfence PKI'),
  scep:               i18n.t('SCEP PKI')
}

export const pkiProvidersTypeOptions = Object.keys(pkiProvidersTypes)
  .sort((a, b) => pkiProvidersTypes[a].localeCompare(pkiProvidersTypes[b]))
  .map(key => ({ value: key, text: pkiProvidersTypes[key] }))
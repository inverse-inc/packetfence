import i18n from '@/utils/locale'

export const routedNetworks = {
  'dns-enforcement':    i18n.t('DNS Enforcement'),
  'inlinel3':           i18n.t('Inline Layer 3'),
  'vlan-isolation':     i18n.t('Isolation'),
  'vlan-registration':  i18n.t('Registration')
}

export const routedNetworkOptions = Object.keys(routedNetworks)
  .sort((a, b) => routedNetworks[a].localeCompare(routedNetworks[b]))
  .map(key => ({ value: key, text: routedNetworks[key] }))


import i18n from '@/utils/locale'

export const types = {
  none:                 i18n.t('None'),
  'dhcp-listener':      i18n.t('DHCP Listener'),
  'dns-enforcement':    i18n.t('DNS Enforcement'),
  inlinel2:             i18n.t('Inline Layer 2'),
  management:           i18n.t('Management'),
  portal:               i18n.t('Portal'),
  'vlan-isolation':     i18n.t('Isolation'),
  'vlan-registration':  i18n.t('Registration'),
  other:                i18n.t('Other')
}

export const typeOptions = Object.keys(types)
  .sort((a, b) => types[a].localeCompare(types[b]))
  .map(key => ({ value: key, text: types[key] }))

export const daemons = {
  dhcp: 'dhcp',
  dns: 'dns',
  portal: 'portal',
  radius: 'radius',
  'dhcp-listener': 'dhcp-listener'
}

export const daemonOptions = Object.keys(daemons)
  .sort((a, b) => daemons[a].localeCompare(daemons[b]))
  .map(key => ({ value: key, text: daemons[key] }))

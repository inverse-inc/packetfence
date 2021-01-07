import i18n from '@/utils/locale'

export const types = {
  BarracudaNG:      i18n.t('BarracudaNG'),
  Checkpoint:       i18n.t('Checkpoint'),
  CiscoIsePic:      i18n.t('Cisco ISE-PIC'),
  FamilyZone:       i18n.t('FamilyZone'),
  FortiGate:        i18n.t('FortiGate'),
  Iboss:            i18n.t('Iboss'),
  JSONRPC:          i18n.t('JSONRPC'),
  JuniperSRX:       i18n.t('JuniperSRX'),
  LightSpeedRocket: i18n.t('LightSpeedRocket'),
  PaloAlto:         i18n.t('PaloAlto'),
  SmoothWall:       i18n.t('SmoothWall'),
  WatchGuard:       i18n.t('WatchGuard')
}

export const typeOptions = Object.keys(types)
  .sort((a, b) => types[a].localeCompare(types[b]))
  .map(key => ({ value: key, text: types[key] }))




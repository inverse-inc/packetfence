import i18n from '@/utils/locale'

export const provisioningTypes = {
  accept:       i18n.t('Accept'),
  airwatch:     i18n.t('Airwatch'),
  android:      i18n.t('Android'),
  deny:         i18n.t('Deny'),
  dpsk:         i18n.t('DPSK'),
  ibm:          i18n.t('IBM'),
  jamf:         i18n.t('Jamf'),
  mobileconfig: i18n.t('Apple Devices'),
  mobileiron:   i18n.t('Mobileiron'),
  opswat:       i18n.t('OPSWAT'),
  packetfence_ztn:  i18n.t('PacketFence Zero Trust Network (ZTN)'),
  sentinelone:  i18n.t('SentinelOne'),
  sepm:         i18n.t('Symantec Endpoint Protection Manager (SEPM)'),
  symantec:     i18n.t('Symantec App Center'),
  windows:      i18n.t('Windows'),
  intune:       i18n.t('Microsoft Intune'),
  servicenow:   i18n.t('ServiceNow'),
  google_workspace_chromebook: i18n.t('Google Workspace Chromebook')
}

export const provisioningTypeOptions = Object.keys(provisioningTypes)
  .sort((a, b) => provisioningTypes[a].localeCompare(provisioningTypes[b]))
  .map(key => ({ value: key, text: provisioningTypes[key] }))

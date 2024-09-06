import i18n from '@/utils/locale'

export const provisioningTypes = {
  accept:       i18n.t('Accept'),
  airwatch:     i18n.t('Airwatch'),
  android:      i18n.t('Android'),
  deny:         i18n.t('Deny'),
  dpsk:         i18n.t('DPSK'),
  jamf:         i18n.t('Jamf'),
  jamfCloud:    i18n.t('Jamf Cloud'),
  kandji:       i18n.t('Kandji'),
  lookup:       i18n.t('Lookup'),
  mobileconfig: i18n.t('Apple Devices'),
  mobileiron:   i18n.t('Mobileiron'),
  sentinelone:  i18n.t('SentinelOne'),
  windows:      i18n.t('Windows'),
  intune:       i18n.t('Microsoft Intune'),
  google_workspace_chromebook: i18n.t('Google Workspace Chromebook')
}

export const provisioningTypeOptions = Object.keys(provisioningTypes)
  .sort((a, b) => provisioningTypes[a].localeCompare(provisioningTypes[b]))
  .map(key => ({ value: key, text: provisioningTypes[key] }))

export const analytics = {
  track: ['provisioningType']
}

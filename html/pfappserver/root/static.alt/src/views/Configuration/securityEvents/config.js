import i18n from '@/utils/locale'

export const triggerCategories = {
  ENDPOINT: 'endpoint',
  PROFILING: 'profiling',
  USAGE: 'usage',
  EVENT: 'event'
}

export const triggerCategoryTitles = {
  [triggerCategories.ENDPOINT]: i18n.t('Endpoint'),
  [triggerCategories.PROFILING]: i18n.t('Device Profiling'),
  [triggerCategories.USAGE]: i18n.t('Usage'),
  [triggerCategories.EVENT]: i18n.t('Event')
}

export const triggerFields = {
  accounting: {
    text: i18n.t('Accounting'),
    category: triggerCategories.USAGE
  },
  custom: {
    text: i18n.t('Custom'),
    category: triggerCategories.EVENT
  },
  detect: {
    text: i18n.t('Detect'),
    category: triggerCategories.EVENT
  },
  device: {
    text: i18n.t('Device'),
    category: triggerCategories.PROFILING
  },
  dhcp_fingerprint: {
    text: i18n.t('DHCP Fingerprint'),
    category: triggerCategories.PROFILING
  },
  dhcp_vendor: {
    text: i18n.t('DHCP Vendor'),
    category: triggerCategories.PROFILING
  },
  dhcp6_fingerprint: {
    text: i18n.t('DHCPv6 Fingerprint'),
    category: triggerCategories.PROFILING
  },
  dhcp6_enterprise: {
    text: i18n.t('DHCPv6 Enterprise'),
    category: triggerCategories.PROFILING
  },
  internal: {
    text: i18n.t('Internal'),
    category: triggerCategories.EVENT
  },
  mac: {
    text: i18n.t('MAC Address'),
    category: triggerCategories.ENDPOINT
  },
  mac_vendor: {
    text: i18n.t('MAC Vendor'),
    category: triggerCategories.PROFILING
  },
  nessus: {
    text: 'Nessus',
    category: triggerCategories.EVENT
  },
  nessus6: {
    text: 'Nessus v6',
    category: triggerCategories.EVENT
  },
  nexpose_event_contains: {
    text: i18n.t('Nexpose event contains ..'),
    category: triggerCategories.EVENT
  },
  nexpose_event_starts_with: {
    text: i18n.t('Nexpose event starts with ..'),
    category: triggerCategories.EVENT
  },
  openvas: {
    text: 'OpenVAS',
    category: triggerCategories.EVENT
  },
  provisioner: {
    text: i18n.t('Provisioner'),
    category: triggerCategories.EVENT
  },
  role: {
    text: i18n.t('Role'),
    category: triggerCategories.ENDPOINT
  },
  suricata_event: {
    text: i18n.t('Suricata Event'),
    category: triggerCategories.EVENT
  },
  suricata_md5: {
    text: 'Suricata MD5',
    category: triggerCategories.EVENT
  },
  switch: {
    text: i18n.t('Switch'),
    category: triggerCategories.ENDPOINT
  },
  switch_group: {
    text: i18n.t('Switch Group'),
    category: triggerCategories.ENDPOINT
  }
}

export const triggerDirections = {
  TOT: i18n.t('Total'),
  IN: i18n.t('Inbound'),
  OUT: i18n.t('Outbound')
}

export const triggerIntervals = {
  D: i18n.t('Day'),
  W: i18n.t('Week'),
  M: i18n.t('Month'),
  Y: i18n.t('Year')
}

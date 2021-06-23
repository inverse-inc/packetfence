import i18n from '@/utils/locale'

//  map friendly reasons,
//  backend reports 1+ reason(s) for delete failure.
//  see: lib/pf/UnifiedApi/Controller/Config/Roles.pm
export const reasons = {
  ADMIN_ROLES_IN_USE:         i18n.t('Admin Roles'),
  BILLING_TIERS_IN_USE:       i18n.t('Billing Tiers'),
  FIREWALL_SSO_IN_USE:        i18n.t('Firewall SSO'),
  NODE_BYPASS_ROLE_ID_IN_USE: i18n.t('Node Bypass Role'),
  NODE_CATEGORY_ID_IN_USE:    i18n.t('Node Category'),
  PASSWORD_CATEGORY_IN_USE:   i18n.t('Password Category'),
  PROVISIONING_IN_USE:        i18n.t('Provisioning'),
  SCAN_IN_USE:                i18n.t('Scans'),
  SECURITY_EVENTS_IN_USE:     i18n.t('Security Events'),
  SELFSERVICE_IN_USE:         i18n.t('Self Service'),
  SWITCH_IN_USE:              i18n.t('Switches')
}

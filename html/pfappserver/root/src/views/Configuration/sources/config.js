import i18n from '@/utils/locale'
import { pfActions } from '@/globals/pfActions'

export const internalTypes = {
  AD:                  i18n.t('Active Directory'),
  Authorization:       i18n.t('Authorization'),
  AzureAD:             i18n.t('Azure AD'),
  EAPTLS:              'EAPTLS',
  EDIR:                'Edirectory',
  Htpasswd:            'Htpasswd',
  GoogleWorkspaceLDAP: 'Google Workspace LDAP',
  HTTP:                'HTTP',
  Kerberos:            'Kerberos',
  LDAP:                'LDAP',
  Potd:                i18n.t('Password Of The Day'),
  RADIUS:              'RADIUS',
  SAML:                'SAML',
}

export const externalTypes = {
  Clickatell:     'Clickatell',
  Email:          i18n.t('Email'),
  Facebook:       'Facebook',
  Github:         'Github',
  Google:         'Google',
  Kickbox:        'Kickbox',
  LinkedIn:       'LinkedIn',
  Null:           i18n.t('Null'),
  OpenID:         'OpenID',
  Pinterest:      'Pinterest',
  SMS:            'SMS',
  SponsorEmail:   i18n.t('Sponsor'),
  Twilio:         'Twilio',
  Twitter:        'Twitter',
  WindowsLive:    'WindowsLive',
}

export const exclusiveTypes = {
  AdminProxy:     i18n.t('AdminProxy'),
  Blackhole:      'Blackhole',
  Eduroam:        'Eduroam',
}

export const billingTypes = {
  Mirapay:        'Mirapay',
  Paypal:         'Paypal',
  Stripe:         'Stripe',
}

export const types = {
  ...internalTypes,
  ...externalTypes,
  ...exclusiveTypes,
  ...billingTypes
}

export const administrationRuleActionsFromSourceType = (sourceType) => ([
  ...[
    pfActions.set_access_level,
    pfActions.set_tenant_id
  ],
  ...((['AD', 'AzureAD', 'LDAP', 'GoogleWorkspaceLDAP', 'EDIR'].includes(sourceType))
    ? [
        pfActions.set_access_durations,
        pfActions.mark_as_sponsor
      ]
    : []
  )
])

export const authenticationRuleActionsFromSourceType = (sourceType) => ([
  ...[
    pfActions.set_role_by_name,
    pfActions.set_access_duration,
    pfActions.set_unreg_date,
    pfActions.set_time_balance,
    pfActions.set_bandwidth_balance,
    pfActions.set_role_from_source
  ],
  ...((['AD', 'AzureAD', 'LDAP', 'GoogleWorkspaceLDAP'].includes(sourceType))
    ? [pfActions.set_role_on_not_found]
    : []
  )
])

import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'domainIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'domainIdentifierNotExistsExcept',
    message: message || i18n.t('Identifier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getDomains').then(response => {
        return response.filter(domain => domain.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

yup.addMethod(yup.string, 'domainUniqueNamesNotExistsExcept', function (except, message) {
  return this.test({
    name: 'domainUniqueNamesNotExistsExcept',
    message: message || i18n.t('Workgroup &amp; DNS name exists.'),
    test: (value) => {
      const { id, dns_name, workgroup } = except
      if (!value) return true
      return store.dispatch('config/getDomains').then(response => {
        return response.filter(domain => domain.id !== id && domain.dns_name.toLowerCase() === dns_name.toLowerCase() && domain.workgroup.toLowerCase() === workgroup.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export default (props) => {
  const {
    id,
    isNew,
    isClone,
    form
  } = props

  const {
    ad_account_lockout_duration,
    ad_account_lockout_threshold,
    ad_fqdn,
    dns_servers,
    nt_key_cache_enabled,
  } = form || {}

  const schemaAdServer = yup.string().nullable().label(i18n.t('IP address')).isIpv4('Invalid IP address.')

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifier required.'))
      .max(10)
      .isAlphaNumeric()
      .domainIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),
    ad_fqdn: yup.string()
      .nullable()
      .required(i18n.t('FQDN required.'))
      .label(i18n.t('FQDN'))
      .isFQDN('Invalid FQDN.'),
    ad_server: yup.string()
      .when('id', {
        is: () => !ad_fqdn || !dns_servers,
        then: schemaAdServer.required(i18n.t('IP address or FQDN required.')),
        otherwise: schemaAdServer
      }),
    dns_name: yup.string().nullable().label(i18n.t('DNS name'))
      .required(i18n.t('Server required.'))
      .isFQDN()
      .domainUniqueNamesNotExistsExcept({ id, ...form }),
    dns_servers: yup.string().nullable().label(i18n.t('Servers'))
      .required(i18n.t('DNS servers required.'))
      .isIpv4Csv(),
    machine_account_password: yup.string().nullable().label(i18n.t('Machine Account Password'))
      .required(i18n.t('Password required.'))
      .min(8, i18n.t('Password must be at least 8 characters.')),
    nt_key_cache_expire: yup.string().nullable()
      .when('id', {
        is: () => nt_key_cache_enabled,
        then: yup.string().minAsInt(60).maxAsInt(864000).required(i18n.t('Cache entry expiration required.')),
        otherwise: yup.string()
      })
      .label(i18n.t('Cache entry expiration')),
    ad_account_lockout_threshold: yup.string().nullable()
      .when('id', {
        is: () => nt_key_cache_enabled,
        then: yup.string().minAsInt(0).maxAsInt(999).required(i18n.t('Account Lockout Threshold required.')),
        otherwise: yup.string().default(0)
      })
      .label(i18n.t('Account Lockout Threshold')),
    ad_account_lockout_duration: yup.string().nullable()
      .when('id', {
        is: () => nt_key_cache_enabled === true && ad_account_lockout_threshold > 0,
        then: yup.string().minAsInt(1).maxAsInt(999).required('"Account Lockout Duration" is required when "Account Lockout Threshold" is enabled.'),
        otherwise: yup.string().default(0)
      })
      .label(i18n.t('Account Lockout Duration')),
    ad_reset_account_lockout_counter_after: yup.string().nullable()
      .when('id', {
          is: () => nt_key_cache_enabled === true && ad_account_lockout_threshold > 0,
          then: yup.string().minAsInt(1).maxAsInt(ad_account_lockout_duration, '"Lockout count resets after" must be less or equal to "Account Lockout Duration".'),
          otherwise: yup.string().default(0)
      })
      .label(i18n.t('Lockout count resets after')),
    max_allowed_password_attempts_per_device: yup.string().nullable()
      .when('id', {
        is: () => nt_key_cache_enabled === true && ad_account_lockout_threshold > 0,
        then: yup.string().minAsInt(1).maxAsInt(ad_account_lockout_threshold, '"Max bad logins per device" must be less or equal than "Account Lockout Threshold".'),
        otherwise: yup.string().default(0)
      })
      .label(i18n.t('Max bad logins per device')),
    ad_old_password_allowed_period: yup.string().minAsInt(0).maxAsInt(99999).nullable().label(i18n.t('Old Password Allowed Period')),
    ntlm_cache_source: yup.string().nullable().label( i18n.t('Source')),
    ntlm_cache_filter: yup.string().nullable().label(i18n.t('Filter')),
    ntlm_cache_expiry: yup.string().nullable().label(i18n.t('Expiration')),
    ou: yup.string().nullable().label('OU'),
    server_name: yup.string().nullable().label(i18n.t('Server name')),
    sticky_dc: yup.string().nullable().label(i18n.t('Sticky DC')),
    workgroup: yup.string().nullable().label(i18n.t('Workgroup'))
      .required(i18n.t('Workgroup required.'))
      .domainUniqueNamesNotExistsExcept({ id, ...form })
  })
}

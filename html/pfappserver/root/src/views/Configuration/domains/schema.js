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

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifier required.'))
      .max(10)
      .isAlphaNumeric()
      .domainIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),
    ad_server: yup.string().nullable().label(i18n.t('Server')).required(i18n.t('Server required.')),
    dns_name: yup.string().nullable().label(i18n.t('DNS name'))
      .required(i18n.t('Server required.'))
      .isFQDN()
      .domainUniqueNamesNotExistsExcept({ id, ...form }),
    dns_servers: yup.string().nullable().label(i18n.t('Servers'))
      .required(i18n.t('Servers required.'))
      .isIpv4Csv(),
    machine_account_password: yup.string().nullable().label(i18n.t('Machine Account Password'))
      .required(i18n.t('Password required.'))
      .min(8),
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

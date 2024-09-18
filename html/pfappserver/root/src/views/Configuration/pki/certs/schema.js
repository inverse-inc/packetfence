import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'pkiCertCnNotExistsExcept', function (exceptCn = '', message) {
  return this.test({
    name: 'pkiCertCnNotExistsExcept',
    message: message || i18n.t('Common name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptCn.toLowerCase()) return true
      return store.dispatch('config/getPkiCerts').then((response) => {
        return response.filter(cert => cert.cn.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export default () => {
  return yup.object().shape({
    profile_id: yup.string()
      .nullable()
      .required(i18n.t('Template required.')),

    cn: yup.string()
      .nullable()
      .required(i18n.t('Common name required.'))
      .max(64, i18n.t('Maximum 64 characters.'))
      .isCommonNameOrFQDNOrMAC(i18n.t('Invalid Common name.')),

    mail: yup.string()
      .nullable()
      .required(i18n.t('Email required.'))
      .email(i18n.t('Invalid email address.'))
      .max(255, i18n.t('Maximum 255 characters.')),

    dns_names: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    ip_addresses: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    organisational_unit: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    organisation: yup.string().max(64, i18n.t('Maximum 64 characters.')),
    country: yup.string(),
    state: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    locality: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    street_address: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    postal_code: yup.string().max(255, i18n.t('Maximum 255 characters.'))
  })
}


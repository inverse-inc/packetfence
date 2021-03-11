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

export default (props) => {
  const {
    isNew,
    isClone,
    form
  } = props

  if (!isNew && !isClone)
    return yup.object() // no validations

  // reactive variables for `yup.when`
  const { cn } = form || {}

  return yup.object().shape({
    profile_id: yup.string()
      .nullable()
      .required(i18n.t('Template required.')),

    cn: yup.string()
      .nullable()
      .required(i18n.t('Common name required.'))
      .max(64, i18n.t('Maximum 64 characters.'))
      .pkiCertCnNotExistsExcept((!isNew && !isClone) ? cn : undefined, i18n.t('Common name exists.'))
      .isCommonName(i18n.t('Invalid Common name.')),

    mail: yup.string()
      .nullable()
      .required(i18n.t('Email required.'))
      .email(i18n.t('Invalid email address.'))
      .max(255),

    organisation: yup.string().required(i18n.t('Organisation required.')).max(64, i18n.t('Maximum 64 characters.')),
    country: yup.string().required(i18n.t('Country required.')),
    state: yup.string().required(i18n.t('State required.')).max(255),
    locality: yup.string().required(i18n.t('Locality required.')).max(255),
    street_address: yup.string().required(i18n.t('Street address required.')).max(255),
    postal_code: yup.string().required(i18n.t('Postal code required.')).max(255)
  })
}


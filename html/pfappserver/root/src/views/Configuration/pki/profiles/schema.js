import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { keyTypes } from '../config'

yup.addMethod(yup.string, 'pkiProfileNameNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'pkiProfileNameNotExistsExcept',
    message: message || i18n.t('Common name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getPkiProfiles').then((response) => {
        return response.filter(profile => profile.name.toLowerCase() === value.toLowerCase()).length === 0
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
  const { name, key_type } = form || {}

  return yup.object().shape({
    ca_id: yup.string()
      .nullable()
      .required(i18n.t('Certificate Authority required.')),

    name: yup.string()
      .nullable()
      .required(i18n.t('Common name required.'))
      .pkiProfileNameNotExistsExcept((!isNew && !isClone) ? name : undefined, i18n.t('Common name exists.'))
      .isCommonName(i18n.t('Invalid Common name.')),

    mail: yup.string()
      .nullable()
      .email(i18n.t('Invalid email address.'))
      .max(255, i18n.t('Maximum 255 characters.')),

    organisation: yup.string().max(64, i18n.t('Maximum 64 characters.')),
    country: yup.string(),
    state: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    locality: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    street_address: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    postal_code: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    key_type: yup.string().required(i18n.t('Key type required.')),
    key_size: yup.string().when('key_type', () => {
      // array to friendly csv, eg: [a, b] => 'a or b', [a, b, c] => 'a, b or c'
      const arrToLocale = (arr) => {
        const exceptLast = arr.slice(0, -1)
        const [ last ] = arr.slice(-1)
        if (exceptLast)
          return i18n.t('{first} or {last}', { first: exceptLast.join(', '), last })
        return last
      }
      const _schema = yup.string().required(i18n.t('Key size required.'))
      const { [key_type]: { text: type, sizes } = {} } = keyTypes
      if (sizes)
        return _schema.in(sizes, i18n.t('Invalid key size. {type} only supports {list}', { type, list: arrToLocale(sizes) }))
      return _schema
    }),
    digest: yup.string().required(i18n.t('Digest required.')),
    validity: yup.string().required(i18n.t('Days required.')).minAsInt(1, i18n.t('Minimum 1 day(s).')).maxAsInt(825, i18n.t('Maximum 825 day(s).')),
    oscp_url: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    p12_mail_password: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    p12_mail_subject: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    p12_mail_from: yup.string().email().max(255, i18n.t('Maximum 255 characters.'))
  })
}


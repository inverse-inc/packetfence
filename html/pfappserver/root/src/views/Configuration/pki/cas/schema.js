import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { keyTypes } from '../config'

yup.addMethod(yup.string, 'pkiCaCnNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'pkiCaCnNotExistsExcept',
    message: message || i18n.t('Common name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getPkiCas').then((response) => {
        return response.filter(ca => ca.ID !== +exceptId && ca.cn.toLowerCase() === value.toLowerCase()).length === 0
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

  if (!isNew && !isClone)
    return yup.object() // no validations

  // reactive variables for `yup.when`
  const { key_type } = form || {}

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifier required.')),

    cn: yup.string()
      .nullable()
      .required(i18n.t('Common name required.'))
      .max(64, i18n.t('Maximum 64 characters.'))
      .pkiCaCnNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Common name exists.'))
      .isCommonNameOrFQDN(i18n.t('Invalid common name.')),

    mail: yup.string()
      .nullable()
      .required(i18n.t('Email required.'))
      .email(i18n.t('Invalid email address.'))
      .max(255),

    organisation: yup.string().required(i18n.t('Organisation required.')).max(64, i18n.t('Maximum 64 characters.')),
    organisational_unit: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    country: yup.string().nullable().required(i18n.t('Country required.')),
    state: yup.string().required(i18n.t('State required.')).max(255),
    locality: yup.string().required(i18n.t('Locality required.')).max(255),
    street_address: yup.string().max(255),
    postal_code: yup.string().max(255),
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
    ocsp_url: yup.string().max(255, i18n.t('Maximum 255 characters.')),
    digest: yup.string().required(i18n.t('Digest required.')),
    days: yup.string().required(i18n.t('Days required.'))
      .minAsInt(1, i18n.t('Minimum 1 day(s).'))
  })
}

import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'pkiProviderIdExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'pkiProviderIdExistsExcept',
    message: message || i18n.t('Detector exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getPkiProviders').then(response => {
        return response.filter(pkiProvider => pkiProvider.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export const schema = (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Detector required.'))
      .pkiProviderIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Detector exists.')),
    ca_cert_path: yup.string().nullable().label(i18n.t('Cert Path')),
    client_cert_path: yup.string().nullable().label(i18n.t('Cert Path')),
    client_key_path: yup.string().nullable().label(i18n.t('Key Path')),
    server_cert_path: yup.string().nullable().label(i18n.t('Cert Path'))
  })
}

export default schema

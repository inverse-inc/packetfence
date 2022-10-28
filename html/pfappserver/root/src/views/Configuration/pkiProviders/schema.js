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
    form,
    id,
    isNew,
    isClone
  } = props

  const {
    ca_cert_path_upload,
    client_cert_path_upload,
    client_key_path_upload,
    server_cert_path_upload
  } = form || {}

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Detector required.'))
      .pkiProviderIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Detector exists.')),
    ca_cert_path: yup.string().nullable().label(i18n.t('CA certificate file'))
      .when('ca_cert_path_upload', () => {
        return (!ca_cert_path_upload)
          ? yup.string().nullable().required(i18n.t('CA certificate file required.'))
          : yup.string().nullable()
      }),
    client_cert_path: yup.string().nullable().label(i18n.t('Cilent certificate file'))
    .when('client_cert_path_upload', () => {
      return (!client_cert_path_upload)
        ? yup.string().nullable().required(i18n.t('Client certificate file required.'))
        : yup.string().nullable()
    }),
    client_key_path: yup.string().nullable().label(i18n.t('Client key file'))
    .when('client_key_path_upload', () => {
      return (!client_key_path_upload)
        ? yup.string().nullable().required(i18n.t('Client key file required.'))
        : yup.string().nullable()
    }),
    server_cert_path: yup.string().nullable().label(i18n.t('Server certificate file'))
    .when('server_cert_path_upload', () => {
      return (!server_cert_path_upload)
        ? yup.string().nullable().required(i18n.t('Server certificate file required.'))
        : yup.string().nullable()
    }),

    url: yup.string().nullable().label('URL'),
    proto: yup.string().nullable().label(i18n.t('Protocol')),
    host: yup.string().nullable().label(i18n.t('Host')),
    port: yup.string().nullable().label(i18n.t('Port')),
    username: yup.string().nullable().label(i18n.t('Username')),
    password: yup.string().nullable().label(i18n.t('Password')),
    profile: yup.string().nullable().label(i18n.t('Profile')),
    country: yup.string().nullable().label(i18n.t('Country')),
    state: yup.string().nullable().label(i18n.t('State')),
    locality: yup.string().nullable().label(i18n.t('Locality')),
    organization: yup.string().nullable().label(i18n.t('Organization')),
    organizational_unit: yup.string().nullable().label(i18n.t('Unit')),
    cn_attribute: yup.string().nullable().label(i18n.t('Attribute')),
    cn_format: yup.string().nullable().label(i18n.t('Format'))
  })
}

export default schema

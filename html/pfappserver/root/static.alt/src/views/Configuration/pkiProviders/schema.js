import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'syslogParserIdExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'syslogParserIdExistsExcept',
    message: message || i18n.t('Detector exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getSyslogParsers').then(response => {
        return response.filter(syslogParser => syslogParser.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .syslogParserIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Detector exists.')),
    ca_cert_path: yup.string().nullable().label(i18n.t('Cert Path')),
    client_cert_path: yup.string().nullable().label(i18n.t('Cert Path')),
    client_key_path: yup.string().nullable().label(i18n.t('Key Path')),
    server_cert_path: yup.string().nullable().label(i18n.t('Cert Path'))
  })
}

export default schema

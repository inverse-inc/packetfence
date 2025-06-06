import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'dnsConnectorIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'dnsConnectorIdentifierNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getConnectorsDns').then(response => {
        return response.filter(connectorDn => connectorDn.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaDomain = yup.string().nullable()
  .required(i18n.t('Domain required.'))
  .isDomain()

const schemaDomains = yup.array().ensure()
  .required(i18n.t('Domain(s) required.'))
  .of(schemaDomain)

export default (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('DNS required.'))
      .dnsConnectorIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('DNS exists.')),
    ip: yup.string()
      .nullable()
      .required(i18n.t('IPv4 required.'))
      .label(i18n.t('IPv4'))
      .isIpv4(),
    port: yup.string()
      .nullable()
      .required(i18n.t('Port required.'))
      .label(i18n.t('Port'))
      .isPort(),
    pfconnectorport: yup.string()
      .nullable()
      .required(i18n.t('Port required.'))
      .label(i18n.t('Port'))
      .isPort(),
    domains: schemaDomains
  })
}

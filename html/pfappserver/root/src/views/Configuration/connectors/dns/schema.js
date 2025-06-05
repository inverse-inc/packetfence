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

const schemaNetwork = yup.string().nullable()
  .required(i18n.t('Network required.'))
  .isCIDR()

const schemaNetworks = yup.array().ensure()
  .unique(i18n.t('Duplicate network.'))
  .of(schemaNetwork)

export default (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Connector ID required.'))
      .dnsConnectorIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Connector ID exists.')),
    description: yup.string()
      .nullable()
      .required(i18n.t('Description required.'))
      .label(i18n.t('Description')),
    secret: yup.string()
      .nullable()
      .required(i18n.t('Secret required.'))
      .label(i18n.t('Secret')),
    networks: schemaNetworks,
  })
}

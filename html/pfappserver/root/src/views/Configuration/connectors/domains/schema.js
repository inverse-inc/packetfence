import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'domainsConnectorIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'domainsConnectorIdentifierNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getConnectorsDomains').then(response => {
        return response.filter(connectorDomain => connectorDomain.id.toLowerCase() === value.toLowerCase()).length === 0
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
    isClone
  } = props

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Domain required.'))
      .domainsConnectorIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Connector ID exists.'))
      .isAlphaNumericHyphenUnderscoreDot(),
    connector: yup.string()
      .nullable()
      .required(i18n.t('Connector required.'))
      .label(i18n.t('Connector')),
  })
}

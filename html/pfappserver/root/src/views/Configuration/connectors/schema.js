import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'connectorIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'connectorIdentifierNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getConnectors').then(response => {
        return response.filter(connector => connector.id.toLowerCase() === value.toLowerCase()).length === 0
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

const schemaDomain = yup.string().nullable()
  .required(i18n.t('Domain required.'))
  .isDomain()

const schemaDomains = yup.array().ensure()
  .unique(i18n.t('Duplicate domain.'))
  .of(schemaDomain)

const schemaDns = yup.object().shape({
  domain: yup.string()
    .nullable()
    .required(i18n.t('Domain required.')),
  port: yup.string()
    .nullable()
    .required(i18n.t('Port required.'))
    .isPort(),
  ip: yup.string()
    .nullable()
    .required(i18n.t('IP required.'))
    .isIpv4(),
  pfconnector_port: yup.string()
    .nullable()
    .required(i18n.t('Connector port required.'))
    .isPort()
})

const schemaDnses = yup.array().ensure()
  .unique(i18n.t('Duplicate domain.'), row => row.domain)
  .of(schemaDns)

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
      .connectorIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Connector ID exists.')),
    description: yup.string()
      .nullable()
      .required(i18n.t('Description required.'))
      .label(i18n.t('Description')),
    secret: yup.string()
      .nullable()
      .required(i18n.t('Secret required.'))
      .label(i18n.t('Secret')),
    networks: schemaNetworks,
    domains: schemaDomains,
    dns: schemaDnses,
  })
}

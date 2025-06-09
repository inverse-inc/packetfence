import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import {
  pfconnectorPortMin,
  pfconnectorPortMax
} from '../config'

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

yup.addMethod(yup.string, 'dnsConnectorPfconnectorportNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'dnsConnectorPfconnectorportNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value) return true
      return store.dispatch('config/getConnectorsDns').then(response => {
        //eslint-disable-next-line
        console.log({exceptName, value, response})
        return response.filter(connectorDn =>  connectorDn.id.toLowerCase() !== exceptName.toLowerCase() && connectorDn.pfconnectorport.toLowerCase() === value.toLowerCase()).length === 0
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

  const portRangeMessage = i18n.t('Port out of range {min}-{max}.', { min: pfconnectorPortMin, max: pfconnectorPortMax } )

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifier required.'))
      .dnsConnectorIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),
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
      .isPort()
      .dnsConnectorPfconnectorportNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Port exists.'))
      .min(pfconnectorPortMin, portRangeMessage)
      .max(pfconnectorPortMax, portRangeMessage),
    domains: schemaDomains
  })
}

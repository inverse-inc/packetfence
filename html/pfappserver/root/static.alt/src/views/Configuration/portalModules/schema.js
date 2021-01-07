import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { schemaActions } from '../sources/schema'

yup.addMethod(yup.string, 'portalModuleIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'portalModuleIdentifierNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getPortalModules').then(response => {
        return response.filter(portalModule => portalModule.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })

    }
  })
})

const schemaModule = yup.string().required(i18n.t('Module required'))

const schemaModules = yup.array().ensure().unique(i18n.t('Duplicate module.')).of(schemaModule)

const schemaSource = yup.string().required(i18n.t('Authentication source required.'))

const schemaSources = yup.array().ensure().unique(i18n.t('Duplicate source.')).of(schemaSource)

export const schema = (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object({
    id: yup.string().label(i18n.t('Name'))
      .portalModuleIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    description: yup.string().label(i18n.t('Description')),
    actions: schemaActions,
    modules: schemaModules,
    multi_source_ids: schemaSources,
    aup_template: yup.string().label(i18n.t('Template')),
    landing_template: yup.string().label(i18n.t('Template')),
    message: yup.string().label(i18n.t('Message')),
    signup_template: yup.string().label(i18n.t('Template')),
    ssl_mobileconfig_path: yup.string().label(i18n.t('URL')),
    ssl_path: yup.string().label(i18n.t('URL')),
    url: yup.string().label(i18n.t('URL')),
    username: yup.string().label(i18n.t('Username'))
  })
}

export default schema

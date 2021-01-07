import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { pfActions as actions } from '@/globals/pfActions'
import { pfFieldType as fieldType } from '@/globals/pfField'

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

const schemaAction = yup.object({
  type: yup.string().nullable().required(i18n.t('Type required.')),
  value: yup.string()
    .when('type', type => ((type && (actions[type].types.includes(fieldType.NONE) || actions[type].types.includes(fieldType.HIDDEN)))
      ? yup.string().nullable()
      : yup.string().nullable().required(i18n.t('Value required.'))
    ))
})

const schemaActions = yup.array().ensure().unique(i18n.t('Duplicate action.'), ({ type }) => type).of(schemaAction)

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
    actions: schemaActions.meta({ invalidFeedback: i18n.t('Actions contain one or more errors.') }),
    modules: schemaModules.meta({ invalidFeedback: i18n.t('Modules contain one or more errors.') }),
    multi_source_ids: schemaSources.meta({ invalidFeedback: i18n.t('Authentication sources contain one or more errors.') }),
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

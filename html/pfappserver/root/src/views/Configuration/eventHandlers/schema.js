import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'eventHandlerIdExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'eventHandlerIdExistsExcept',
    message: message || i18n.t('Detector exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getEventHandlers').then(response => {
        return response.filter(eventHandler => eventHandler.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaRuleAction = yup.object({
  api_method: yup.string().nullable().required(i18n.t('Method required.')),
  api_parameters: yup.string().nullable().required(i18n.t('Parameters required.'))
})

const schemaRuleActions = yup.array().ensure().of(schemaRuleAction.meta({ invalidFeedback: i18n.t('Action contains one or more errors.') }))

const schemaRule = yup.object({
  name: yup.string().nullable().required(i18n.t('Name required.')),
  regex: yup.string().nullable().required(i18n.t('Regex required.')),
  actions: schemaRuleActions.label(i18n.t('Actions')).meta({ invalidFeedback: i18n.t('Actions contain one or more errors.') })
})

const schemaRules = yup.array().ensure().of(schemaRule.meta({ invalidFeedback: i18n.t('Rule contains one or more errors.') }))

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
      .eventHandlerIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Detector exists.')),
    path: yup.string()
      .nullable()
      .label(i18n.t('Alert pipe'))
      .required(i18n.t('Alert pipe required.')),
    rules: schemaRules.label(i18n.t('Rules')).meta({ invalidFeedback: i18n.t('Rules contain one or more errors.') })
  })
}

export default schema

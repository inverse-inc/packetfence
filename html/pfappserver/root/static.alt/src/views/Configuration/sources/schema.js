import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'sourceIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'sourceIdNotExistsExcept',
    message: message || i18n.t('Source exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getSources').then(response => {
        return response.filter(source => source.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaRuleAction = yup.object({
  type: yup.string().required(i18n.t('Type required.')),
  value: yup.string().required(i18n.t('Value required'))
})

const schemaRuleActions = yup.array().of(schemaRuleAction)

const schemaRule = yup.object({
  status: yup.string(),
  id: yup.string().meta({ fieldName: i18n.t('Name') }),
  description: yup.string(),
  match: yup.string(),
  actions: schemaRuleActions.meta({ fieldName: i18n.t('Action'), invalidFeedback: i18n.t('Action contains one or more errors.') }),
  conditions: yup.array().meta({ fieldName: i18n.t('Condition'), invalidFeedback: i18n.t('Condition contains one or more errors.') })
})

const schemaRules = yup.array().of(schemaRule)

export const schema = (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .sourceIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),

    administration_rules: schemaRules.meta({ invalidFeedback: i18n.t('Administration rule contains one or more errors.') }),
    authentication_rules: schemaRules.meta({ invalidFeedback: i18n.t('Authentication rule contains one or more errors.') }),

  })
}

export default schema

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

const schemaRuleActions = yup.array().ensure().of(schemaRuleAction)

const schemaRuleCondition = yup.object({
  attribute: yup.string().label(i18n.t('Attribute')).required(i18n.t('Attribute required.')),
  operator: yup.string().label(i18n.t('Operator')).required(i18n.t('Operator required.')),
  value: yup.string().label(i18n.t('Value')).required(i18n.t('Value required.'))
})

const schemaRuleConditions = yup.array().ensure().of(schemaRuleCondition)

const schemaRule = yup.object({
  status: yup.string(),
  id: yup.string().label(i18n.t('Name')),
  description: yup.string(),
  match: yup.string(),
  actions: schemaRuleActions.label(i18n.t('Action')).meta({ invalidFeedback: i18n.t('Action contains one or more errors.') }),
  conditions: schemaRuleConditions.label(i18n.t('Condition')).meta({ invalidFeedback: i18n.t('Condition contains one or more errors.') })
})

const schemaRules = yup.array().ensure().of(schemaRule)

const schemaPersonMapping = yup.object({
  person_field: yup.string().nullable().required('Person field required.'),
  openid_field: yup.string().nullable().required('OpenID field required.')
})

const schemaPersonMappings = yup.array().ensure().of(schemaPersonMapping)

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
    port: yup.string().isPort(),

    basedn: yup.string().label(i18n.t('Base DN')),
    description: yup.string().label(i18n.t('Description')),
    host: yup.string().label(i18n.t('Host')),
    person_mappings: schemaPersonMappings.meta({ invalidFeedback: i18n.t('Mappings contain one or more errors.') }),
  })
}

export default schema

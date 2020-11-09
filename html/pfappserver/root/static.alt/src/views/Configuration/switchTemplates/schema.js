import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'switchTemplateIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'switchTemplateIdNotExistsExcept',
    message: message || i18n.t('Switch template exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getSwitchTemplates').then(response => {
        return response.filter(switchTemplate => switchTemplate.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaRadiusAttribute = yup.object({
  type: yup.string().nullable().required(i18n.t('Type required.')),
  value: yup.string()
    .when('type', {
      is: value => !value,
      then: yup.string().nullable(),
      otherwise: yup.string().nullable().required(i18n.t('Value required.'))
    })
})

const schemaRadiusAttributes = yup.array().ensure().of(schemaRadiusAttribute.meta({ invalidFeedback: i18n.t('Scope contains one or more errors.') }))

export const schema = (props) => {
  const {
    isNew,
    isClone,
    id,
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifier required.'))
      .switchTemplateIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),

    acceptVlan: schemaRadiusAttributes.meta({ invalidFeedback: i18n.t('VLAN scopes contain one or more errors.') }),
    acceptRole: schemaRadiusAttributes.meta({ invalidFeedback: i18n.t('Role scopes contain one or more errors.') }),
    disconnect: schemaRadiusAttributes.meta({ invalidFeedback: i18n.t('Diisconnect scopes contain one or more errors.') }),
    coa: schemaRadiusAttributes.meta({ invalidFeedback: i18n.t('CoA scopes contain one or more errors.') }),
    reject: schemaRadiusAttributes.meta({ invalidFeedback: i18n.t('Reject scopes contain one or more errors.') }),
    voip: schemaRadiusAttributes.meta({ invalidFeedback: i18n.t('VOIP scopes contain one or more errors.') }),
  })
}

export default schema

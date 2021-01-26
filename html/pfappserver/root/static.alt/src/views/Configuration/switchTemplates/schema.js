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
  type: yup.string().nullable().required(i18n.t('RADIUS attribute required.')),
  value: yup.string()
    .when('type', type => ((type)
      ? yup.string().nullable().required(i18n.t('Value required.'))
      : yup.string().nullable()
    ))
})

const schemaRadiusAttributes = yup.array().ensure().unique(i18n.t('Duplicate attribute.')).of(schemaRadiusAttribute)

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

    acceptVlan: schemaRadiusAttributes,
    acceptRole: schemaRadiusAttributes,
    bounce: schemaRadiusAttributes,
    disconnect: schemaRadiusAttributes,
    cliAuthorizeRead: schemaRadiusAttributes,
    cliAuthorizeWrite: schemaRadiusAttributes,
    coa: schemaRadiusAttributes,
    reject: schemaRadiusAttributes,
    voip: schemaRadiusAttributes,
  })
}

export default schema

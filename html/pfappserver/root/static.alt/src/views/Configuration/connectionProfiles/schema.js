import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'connectionProfileIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'connectionProfileIdNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getConnectionProfiles').then(response => {
        return response.filter(connectionProfile => connectionProfile.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaFilter = yup.object({
  type: yup.string().required(i18n.t('Type required.')),
  match: yup.string().required(i18n.t('Match required'))
})

const schemaFilters = yup.array().ensure().of(schemaFilter)

const schemaAdvancedFilter = yup.object({
  field: yup.string().required(i18n.t('Field required.')),
  op: yup.string().required(i18n.t('Operator required.')),
  value: yup.string().required(i18n.t('Value required.')),
  values: yup.array().ensure().of(
    yup.lazy(() => { // avoid infinite nesting when casted
      return schemaAdvancedFilter.default(undefined) // recurse self
    })
  )
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
      .required(i18n.t('Name required.'))
      .connectionProfileIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),

    filter: schemaFilters.meta({ invalidFeedback: i18n.t('Filter contains one or more errors.') }),
    advanced_filter: schemaAdvancedFilter.meta({ invalidFeedback: i18n.t('Advanced filter contains one or more errors.') })
  })
}

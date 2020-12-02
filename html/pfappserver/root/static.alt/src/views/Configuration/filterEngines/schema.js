import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'filterIdNotExistsExcept', function (except, message) {
  const { collection, id = '' } = except
  return this.test({
    name: 'filterIdNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === id.toLowerCase()) return true
      return store.dispatch('$_filter_engines/getCollection', collection).then(response => {
        const { items = [] } = response || {}
        return items.filter(filter => filter.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaAction = yup.object({
  api_method: yup.string().required(i18n.t('Method required.')),
  api_parameters: yup.string().required(i18n.t('Parameters required.'))
})

const schemaActions = yup.array().ensure().of(schemaAction)

const schemaAnswer = yup.object({
  prefix: yup.string().required(i18n.t('Prefix required.')),
  type: yup.string().required(i18n.t('Type required.')),
  value: yup.string().required(i18n.t('Value required'))
})

const schemaAnswers = yup.array().ensure().of(schemaAnswer)

const schemaCondition = yup.object({
  field: yup.string().required(i18n.t('Field required.')),
  op: yup.string().required(i18n.t('Operator required.')),
  value: yup.string().required(i18n.t('Value required.')),
  values: yup.array().ensure().of(
    yup.lazy(() => { // avoid infinite nesting when casted
      return schemaCondition.default(undefined) // recurse self
    })
  )
})

export const schema = (props) => {
  const {
    collection,
    id,
    isNew,
    isClone
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .filterIdNotExistsExcept((!isNew && !isClone) ? { collection, id } : { collection }, i18n.t('Name exists.')),

    actions: schemaActions.meta({ invalidFeedback: i18n.t('Actions contain one or more errors.') }),
    answers: schemaAnswers.meta({ invalidFeedback: i18n.t('Answers contain one or more errors.') }),
    condition: schemaCondition.meta({ invalidFeedback: i18n.t('Condition contains one or more errors.') })
  })
}

export default schema

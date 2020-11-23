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

const schemaAnswer = yup.object({
  prefix: yup.string().required(i18n.t('Prefix required.')),
  type: yup.string().required(i18n.t('Type required.')),
  value: yup.string().required(i18n.t('Value required'))
})

const schemaAnswers = yup.array().ensure().of(schemaAnswer)

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

    answers: schemaAnswers.meta({ fieldName: i18n.t('Answer'), invalidFeedback: i18n.t('Answers contain one or more errors.') }),
  })
}

export default schema

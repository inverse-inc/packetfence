import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'remoteConnectionProfileIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'remoteConnectionProfileIdNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getRemoteConnectionProfiles').then(response => {
        return response.filter(remoteConnectionProfile => remoteConnectionProfile.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaAdvancedFilter = yup.object({
  field: yup.string().required(i18n.t('Field required.')),
  op: yup.string().nullable().required(i18n.t('Operator required.')),
  value: yup.string().required(i18n.t('Value required.')),
  values: yup.array().ensure().of(
    yup.lazy(() => { // avoid infinite nesting when casted
      return schemaAdvancedFilter.default(undefined) // recurse self
    })
  )
}).nullable()

export default (props) => {

  const {
    id,
    form,
    isNew,
    isClone
  } = props

  // reactive variables for `yup.when`
  const { basic_filter_type } = form || {}

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .remoteConnectionProfileIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    basic_filter_type: yup.string().nullable(),
    basic_filter_value: yup.string()
      .when('basic_filter_type', () => {
        switch(basic_filter_type) {
          case 'node_info.mac':
            return yup.string().nullable().required(i18n.t('MAC required.'))
            // break
          case 'node_info.pid':
            return yup.string().nullable().required(i18n.t('Username required.'))
            // break
          case 'node_info.category':
            return yup.string().nullable().required(i18n.t('Role required.'))
            // break
          default:
            return yup.string().nullable()
        }
      }),
    advanced_filter: schemaAdvancedFilter.meta({ invalidFeedback: i18n.t('Advanced filter contains one or more errors.') })
  })
}

export { yup }

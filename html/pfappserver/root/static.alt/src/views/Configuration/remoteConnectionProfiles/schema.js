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
  const { advanced_filter, basic_filter_type } = form || {}

  // eval out-of-band to avoid cyclic
  let _basic_filter_type
  if (!basic_filter_type && !(advanced_filter && advanced_filter.values.length)) // both filters empty
    _basic_filter_type = yup.string().nullable().required(i18n.t('Filter or Advanced Filter required.'))
  else // at least one filter defined
    _basic_filter_type = yup.string().nullable()

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .remoteConnectionProfileIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    advanced_filter: yup.object()
      .when('basic_filter_type', () => (basic_filter_type)
        ? yup.object().nullable() // don't validate when basic_filter_type is set
        : schemaAdvancedFilter.meta({ invalidFeedback: i18n.t('Advanced filter contains one or more errors.') })
       ),
    basic_filter_type: _basic_filter_type,
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
    description: yup.string().nullable().label(i18n.t('Description')),
    internal_domain_to_resolve: yup.string().nullable().label(i18n.t('Domain')),
    stun_server: yup.string().nullable().label(i18n.t('Server'))
  })
}

export { yup }

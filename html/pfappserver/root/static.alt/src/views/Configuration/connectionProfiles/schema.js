import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { pfFiltersSchema as schemaFilters } from '@/globals/pfFilters'

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

yup.addMethod(yup.string, 'pathNotExists', function (entries, path, message) {
  return this.test({
    name: 'pathNotExists',
    message: message || i18n.t('File exists.'),
    test: (value) => {
      if (!value)
        return true
      // point @ primitive
      let ptrEntries = entries.value
      // traverse tree using path parts
      let parts = path.value.split('/').filter(p => p)
      while (parts.length > 0) {
        for (let e = 0; e < ptrEntries.length; e++) {
          const { name, entries: childEntries = [] } = ptrEntries[e]
          if (name === parts[0]) {
            // update pointer
            ptrEntries = childEntries
            break
          }
        }
        parts = parts.slice(1)
      }
      for (let e = 0; e < ptrEntries.length; e++) {
        const { name } = ptrEntries[e]
        if (name === value.trim())
          return false
      }
      return true
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

const schemaArrayItem = yup.string().required().label('Value')

const schemaArray = yup.array().of(schemaArrayItem)

export default (props) => {
  const {
    form,
    id,
    isNew,
    isClone
  } = props

  const { advanced_filter } = form || {}

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .connectionProfileIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    advanced_filter: schemaAdvancedFilter,
    billing_tiers: schemaArray.unique(i18n.t('Duplicate billing tier.')),
    default_psk_key: yup.string().nullable().label(i18n.t('Key')),
    description: yup.string().nullable().label(i18n.t('Description')),
    filter: yup.array()
      .when('advanced_filter', () => {
        const { values = [] } = advanced_filter || {}
        return (values.length === 0)
          ? yup.array().ensure().if(value => value && value.length > 0, i18n.t('Filter or Advanced Filter required.'))
          : schemaFilters
      }),
    filter_match_style: yup.string().nullable().label(i18n.t('Filters')),
    locale: schemaArray.unique(i18n.t('Duplicate locale.')),
    login_attempt_limit: yup.string().nullable().label( i18n.t('Limit')),
    logo: yup.string().nullable().label(i18n.t('Logo')),
    provisioners: schemaArray.unique(i18n.t('Duplicate provisioner.')),
    redirecturl: yup.string().nullable().label(i18n.t('Redirect')),
    root_module: yup.string().nullable().label(i18n.t('Module')),
    scans: schemaArray.unique(i18n.t('Duplicate scanner.')),
    self_service: yup.string().nullable().label(i18n.t('Registration')),
    sms_pin_retry_limit: yup.string().nullable().label(i18n.t('Limit')),
    sms_request_limit: yup.string().nullable().label(i18n.t('Limit')),
    sources: schemaArray.unique(i18n.t('Duplicate source.')),
    vlan_pool_technique: yup.string().nullable().label(i18n.t('Algorithm'))
  })
}

export { yup }

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

const schemaArrayItem = yup.string().required().label('Value')

const schemaArray = yup.array().of(schemaArrayItem)

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

    filter: schemaFilters.unique(i18n.t('Duplicate filter.')),
    advanced_filter: schemaAdvancedFilter.meta({ invalidFeedback: i18n.t('Advanced filter contains one or more errors.') }),
    sources: schemaArray.unique(i18n.t('Duplicate source.')),
    billing_tiers: schemaArray.unique(i18n.t('Duplicate billing tier.')),
    provisioners: schemaArray.unique(i18n.t('Duplicate provisioner.')),
    scans: schemaArray.unique(i18n.t('Duplicate scanner.')),
    locale: schemaArray.unique(i18n.t('Duplicate locale.')),
    root_module: yup.string().label(i18n.t('Module'))
  })
}

export { yup }

import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'roleNameOrCategoryIdentifierExists', function (message) {
  return this.test({
    name: 'roleCategoryIdentifierExists',
    message: message || i18n.t('Role does not exist.'),
    test: (value) => {
      if (!value) return true
      return store.dispatch('config/getRoles').then(response => {
        return (/^\d+$/.test(value)) // is numeric?
          ? response.filter(role => role.category_id === value).length > 0
          : response.filter(role => role.name.toLowerCase() === value.toLowerCase()).length > 0
      }).catch(() => {
        return true
      })
    }
  })
})

yup.addMethod(yup.string, 'roleNameNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'roleNameNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getRoles').then(response => {
        return response.filter(role => role.name.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

yup.addMethod(yup.string, 'parentIsNotIdentifier', function (id = '', message) {
  return this.test({
    name: 'parentIsNotIdentifier',
    message: message || i18n.t('Invalid parent, must not be self.'),
    test: (value) => (!value || value.toLowerCase() !== id.toLowerCase())
  })
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
      .roleNameNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    notes: yup.string().nullable(),
    max_nodes_per_pid: yup.string().nullable(),
    parent: yup.string().nullable()
      .parentIsNotIdentifier(id)
  })
}

export { yup }

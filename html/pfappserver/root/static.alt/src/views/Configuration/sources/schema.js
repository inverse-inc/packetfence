import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'roleNameNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'roleNameNotExistsExcept',
    message: message || i18n.t('Role exists.'),
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

    notes: yup.string()
      .nullable(),

    max_nodes_per_pid: yup.string()
      .nullable()
  })
}

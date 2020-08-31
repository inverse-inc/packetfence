import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'nameNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'nameNotExistsExcept',
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

export default (context) => {
  const {
    id,
    isNew,
    isClone
  } = context

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .nameNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),

    notes: yup.string()
      .nullable(),

    max_nodes_per_pid: yup.string()
      .nullable()
  })
}

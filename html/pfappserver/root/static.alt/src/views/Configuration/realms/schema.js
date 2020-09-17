import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'realmIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'realmIdentifierNotExistsExcept',
    message: message || i18n.t('Realm exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getRealms').then(response => {
        return response.filter(role => role.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .required(i18n.t('Realm required.'))
      .realmIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Realm exists.')),


/*
    ldap_source:
*/
  })
}

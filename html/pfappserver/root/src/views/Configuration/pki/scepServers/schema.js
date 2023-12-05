import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'pkiScepServerNameNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'pkiScepServerNameNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value) return true
      return store.dispatch('config/getPkiScepServers').then((response) => {
        return response.filter(scepserver => scepserver.ID !== +exceptId && scepserver.name.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export default (props) => {
  const {
    isNew,
    isClone,
    form
  } = props

  // reactive variables for `yup.when`
  const { id } = form || {}

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifier required.')),

    name: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .pkiScepServerNameNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),

    url: yup.string()
      .nullable()
      .required(i18n.t('URL required.')),

    shared_secret: yup.string()
      .nullable()
      .required(i18n.t('Secret required.')),

  })
}

import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'pkiScepServerNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'pkiScepServerNotExistsExcept',
    message: message || i18n.t('Identifier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getPkiScepServers').then((response) => {
        return response.filter(scepserver => scepserver.id !== +exceptId && scepserver.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .required(i18n.t('Identifier required.'))
      .pkiScepServerNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),

    name: yup.string()
      .nullable()
      .required(i18n.t('Name required.')),

    url: yup.string()
      .nullable()
      .required(i18n.t('URL required.')),

    shared_secret: yup.string()
      .nullable()
      .required(i18n.t('Secret required.')),

  })
}

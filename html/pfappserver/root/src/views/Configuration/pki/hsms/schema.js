import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'pkiHsmNameNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'pkiHsmNameNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value) return true
      return store.dispatch('config/getPkiHsms').then((response) => {
        return response.filter(hsm => hsm.ID !== +exceptId && hsm.name.toLowerCase() === value.toLowerCase()).length === 0
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
      .pkiHsmNameNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),

    module: yup.string()
      .nullable()
      .required(i18n.t('Module required.')),

    token_label: yup.string()
      .nullable()
      .required(i18n.t('Token label required.')),

    pin: (isNew || isClone)
      ? yup.string().nullable().required(i18n.t('PIN required.'))
      : yup.string().nullable(),

  })
}

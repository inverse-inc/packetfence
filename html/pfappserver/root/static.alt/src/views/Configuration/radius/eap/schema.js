import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'radiusEapIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'radiusEapIdNotExistsExcept',
    message: message || i18n.t('Identifier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getRadiusEaps').then(response => {
        return response.filter(eap => eap.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .required(i18n.t('Identifier required.'))
      .radiusEapIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.'))
  })
}

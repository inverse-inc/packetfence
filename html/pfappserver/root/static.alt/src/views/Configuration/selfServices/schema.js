import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'selfServiceIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'selfServiceIdentifierNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getSelfServices').then(response => {
        return response.filter(selfService => selfService.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .selfServiceIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.'))

  })
}

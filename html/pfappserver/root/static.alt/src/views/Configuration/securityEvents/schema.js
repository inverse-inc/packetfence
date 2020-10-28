import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'securityEventIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'securityEventIdNotExistsExcept',
    message: message || i18n.t('Identifier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getSecurityEvents').then(response => {
        return Object.keys(response).filter(item => item.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export const schema = (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .securityEventIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),

  })
}

export default schema

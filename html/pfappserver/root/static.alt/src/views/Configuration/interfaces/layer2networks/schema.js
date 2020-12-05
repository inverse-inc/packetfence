import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'layer2NetworkIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'layer2NetworkIdNotExistsExcept',
    message: message || i18n.t('Netowrk exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getLayer2Networks').then(response => {
        return response.filter(layer2Network => layer2Network.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .required(i18n.t('Network required.'))
      .layer2NetworkIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Netowrk exists.'))
  })
}

export default schema

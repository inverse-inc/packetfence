import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'syslogForwarderIdExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'syslogForwarderIdExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getSyslogForwarders').then(response => {
        return response.filter(syslogForwarder => syslogForwarder.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .syslogForwarderIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    proto: yup.string().label(i18n.t('Protocol')),
    host: yup.string().label(i18n.t('Host'))
  })
}

export default schema

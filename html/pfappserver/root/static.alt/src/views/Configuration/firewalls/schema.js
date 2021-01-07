import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'firewallIdExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'firewallIdExistsExcept',
    message: message || i18n.t('Hostname or IP Address exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getFirewalls').then(response => {
        return response.filter(firewall => firewall.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .required(i18n.t('Hostname or IP Address required.'))
      .firewallIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Hostname or IP Address exists.')),

    password: yup.string().nullable().label(i18n.t('Secret or Key')),
    username: yup.string().nullable().label(i18n.t('Username'))
  })
}

export default schema

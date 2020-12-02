import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'wmiRuleNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'wmiRuleNotExistsExcept',
    message: message || i18n.t('WMI Rule exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getWmiRules').then(response => {
        return response.filter(wmiRule => wmiRule.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .required(i18n.t('WMI Rule required.'))
      .wmiRuleNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('WMI Rule exists.'))
  })
}

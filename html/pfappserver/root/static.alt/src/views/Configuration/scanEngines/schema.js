import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'scanEngineIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'scanEngineIdentifierNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getScans').then(response => {
        return response.filter(scan => scan.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaWmiRule = yup.string().label(i18n.t('WMI Rule')).required(i18n.t('WMI Rule required.'))

const schemaWmiRules = yup.array().ensure().of(schemaWmiRule)

export default (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object().shape({
    id: yup.string().label(i18n.t('Name'))
      .nullable()
      .scanEngineIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),

    ip: yup.string().label(i18n.t('IP')),
    username: yup.string().label(i18n.t('Username')),
    password: yup.string().label(i18n.t('Password')),

    wmi_rules: schemaWmiRules.label(i18n.t('WMI Rules')).meta({ invalidFeedback: i18n.t('WMI Rules contain one or more errors.') })
  })
}

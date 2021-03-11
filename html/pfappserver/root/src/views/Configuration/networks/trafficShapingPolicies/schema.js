import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'trafficShapingPolicyIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'trafficShapingPolicyIdentifierNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getTrafficShapingPolicies').then(response => {
        return response.filter(trafficShapingPolicy => trafficShapingPolicy.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export default (props) => {
  const {
    id,
    isNew
  } = props

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .trafficShapingPolicyIdentifierNotExistsExcept((!isNew) ? id : undefined, i18n.t('Name exists.')),
    upload: yup.string().nullable().label(i18n.t('Upload')),
    download: yup.string().nullable().label(i18n.t('Download'))
  })
}

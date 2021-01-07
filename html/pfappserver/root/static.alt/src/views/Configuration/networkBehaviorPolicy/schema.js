import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'networkBehaviorPolicyIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'networkBehaviorPolicyIdNotExistsExcept',
    message: message || i18n.t('Source exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getNetworkBehaviorPolicies').then(response => {
        return response.filter(policy => policy.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaDeviceAttribute = yup.object({
  type: yup.string().nullable().required('Attribute required.'),
  value: yup.string()
    .when('type', type => ((type)
      ? yup.string().nullable().required(i18n.t('Weight required.'))
      : yup.string().nullable()
    ))
})

const schemaDeviceAttributes = yup.array().unique(i18n.t('Duplicate attribute.'), ({ type }) => type).of(schemaDeviceAttribute)

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
      .networkBehaviorPolicyIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Profile exists.')),

    device_attributes_diff_threshold_overrides: schemaDeviceAttributes
  })
}

export default schema

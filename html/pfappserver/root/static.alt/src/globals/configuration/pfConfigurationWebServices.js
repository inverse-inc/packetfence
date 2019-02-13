import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'

const {
  maxLength
} = require('vuelidate/lib/validators')

export const pfConfigurationWebServicesViewFields = (context = {}) => {
  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('Username'),
          text: i18n.t('The webservices user name.'),
          fields: [
            {
              key: 'user',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Password'),
          text: i18n.t('The webservices password.'),
          fields: [
            {
              key: 'pass',
              component: pfFormPassword,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        }
      ]
    }
  ]
}

export const pfConfigurationWebServicesViewDefaults = (context = {}) => {
  return {}
}

export const pfConfigurationWebServicesViewPlaceholders = (context = {}) => {
  return {}
}

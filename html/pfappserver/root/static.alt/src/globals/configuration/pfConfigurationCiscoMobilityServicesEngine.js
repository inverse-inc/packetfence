import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'

const {
  maxLength
} = require('vuelidate/lib/validators')

export const pfConfigurationCiscoMobilityServicesEngineViewFields = (context = {}) => {
  const {
    form,
    placeholders
  } = context
  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('Enable MSE'),
          text: i18n.t('Enable MSE.'),
          fields: [
            {
              key: 'enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('URL of MSE service'),
          text: i18n.t('URL of MSE service.'),
          fields: [
            {
              key: 'url',
              component: pfFormInput,
              validators: {
                [i18n.t('Maximum 255 characters.')]: maxLength(255)
              }
            }
          ]
        },
        {
          label: i18n.t('Username'),
          text: i18n.t('Username for MSE service.'),
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
          text: i18n.t('Password for MSE service.'),
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

export const pfConfigurationCiscoMobilityServicesEngineViewDefaults = (context = {}) => {
  return {}
}

export const pfConfigurationCiscoMobilityServicesEngineViewPlaceholders = (context = {}) => {
  return {}
}
